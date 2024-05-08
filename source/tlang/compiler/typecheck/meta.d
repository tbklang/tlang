module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity, Function, FunctionCall, IdentExpression;
import tlang.compiler.symbols.expressions : Expression, IntegerLiteral, IntegerLiteralEncoding;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.containers : Container;
import tlang.compiler.symbols.mcro;
import tlang.compiler.typecheck.core;
import tlang.misc.logging;
import std.conv : to;
import tlang.compiler.configuration;
import tlang.compiler.symbols.aliases : AliasDeclaration;
import std.string : format;

/** 
 * The `MetaProcessor` is used to do a pass over a `Container`
 * to process any macro and macro-like entities
 */
public class MetaProcessor
{
    private TypeChecker tc;
    private bool isMetaEnabled;
    private CompilerConfiguration compilerConfig;

    /** 
     * Constructs a new `MetaProcessor` for the purposes of
     * modifying the AST tree before the typechecker traverses
     * it
     *
     * Params:
     *   tc = the `TypeChecker` instance to process
     *   isMetaEnabled = `true` if to perform meta processing, otherwise `false`
     */
    this(TypeChecker tc, bool isMetaEnabled)
    {
        this.tc = tc;
        this.isMetaEnabled = isMetaEnabled;
        this.compilerConfig = tc.getConfig();
    }

    /** 
     * Analyzes the provided `Container` and searches for any `Macro`-like
     * parse-nodes to process
     */
    public void process(Container container)
    {
        /* Only apply meta-processing if enabled */
        if(!isMetaEnabled)
        {
            return;
        }

        /* Get all statements */
        Statement[] stmts = container.getStatements();

        foreach(Statement curStmt; stmts)
        {
            DEBUG("MetaProcessor: Examining AST node '"~curStmt.toString()~"'...");

            // Perform replacement of all type alises to concrete types, such as `size_t`
            doTypeAlias(container, curStmt);

            // Perform alias expression replacement (TODO: Should this be here?)
            doAliasExpression(container, curStmt);

            /**
             * Search for any `sizeof(<ident_type>)` expressions
             * and replace them with a `NumberLiteral`
             */
            if(cast(MStatementSearchable)curStmt && cast(MStatementReplaceable)curStmt)
            {
                MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
                Statement[] foundStmts = searchableStmt.search(FunctionCall.classinfo);
                DEBUG("Nah fr");

                foreach(Statement curFoundStmt; foundStmts)
                {
                    FunctionCall curFuncCall = cast(FunctionCall)curFoundStmt;

                    if(curFuncCall.getName() == "sizeof")
                    {
                        DEBUG("Elo");
                        Expression[] arguments = curFuncCall.getCallArguments();
                        if(arguments.length == 1)
                        {
                            IdentExpression potentialIdentExp = cast(IdentExpression)arguments[0];
                            if(potentialIdentExp)
                            {
                                string typeName = potentialIdentExp.getName();
                                IntegerLiteral replacementStmt = sizeOf_Literalize(typeName);
                                DEBUG("sizeof: Replace '"~curFoundStmt.toString()~"' with '"~replacementStmt.toString()~"'");

                                /* Traverse down from the `Container` we are process()'ing and apply the replacement */
                                MStatementReplaceable containerRepl = cast(MStatementReplaceable)container;
                                containerRepl.replace(curFoundStmt, replacementStmt);
                            }
                            else
                            {
                                // TODO: Throw an exception here that an ident_type should be present as the argument
                                ERROR("The argument to `sizeof` should be an ident");
                            }
                        }
                        else
                        {
                            // TODO: Throw an exception here as only 1 argument is allowed
                            ERROR("To use the `sizeof` macro you require a single argument to be passed to it");
                        }
                    }
                }
            }

            /** 
             * If the current statement is a Container then recurse
             * 
             * This will help us do the following:
             *
             * 1. Type re-writing of
             *      a. Functions (Parameters and Body as both make up its Statement[])
             */
            if(cast(Container)curStmt)
            {
                process(cast(Container)curStmt);
            }
        }
    }

    import niknaks.arrays : filter;
    import niknaks.functional : predicateOf, Predicate;
    import tlang.compiler.symbols.data : VariableExpression;
    import std.string : cmp;

    private void doAliasExpression(Container container, Statement curStmt)
    {
        bool oldCode = false;

        import tlang.compiler.typecheck.resolution : Resolver;
        Resolver resolver = tc.getResolver();

        // Discover all declared aliases in current container
        // TODO: Ordering might be a parameter to set (as this discovers alias declared even AFTER they are used)
        bool isAliasDecl(Statement stmt)
        {
            return cast(AliasDeclaration)stmt !is null;
        }
        Statement[] declaredAliasesStmts;
        resolver.collectUpwards(container, predicateOf!(isAliasDecl), declaredAliasesStmts);
        AliasDeclaration[] declaredAliases = cast(AliasDeclaration[])declaredAliasesStmts;

        DEBUG(format("All aliases available from (cntnr:%s, stmt=%s) upwards: %s", container, curStmt, declaredAliases));

        // Find any VariableExpression(s) from curStmt (TODO: should be container or nah?)
        MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
        if(searchableStmt)
        {
            VariableExpression[] foundStmts = cast(VariableExpression[])searchableStmt.search(VariableExpression.classinfo);

            // Now, for all VariableExpressions, do
            foreach(VariableExpression varExp; foundStmts)
            {
                // Extract the name/referent, then match all aliases
                // that have the same name
                // (these should have been generated from closest to
                // furthest when obtained from the resolver, so any
                // tie breaking would be the logically closest 
                // alias with the same name)
                AliasDeclaration[] matched;
                string varExpIdent = varExp.getName();
                bool filterAliasesToName(AliasDeclaration aliasDecl)
                {
                    return cmp(aliasDecl.getName(), varExpIdent) == 0;
                }    
                filter!(AliasDeclaration)(declaredAliases, predicateOf!(filterAliasesToName), matched);

                DEBUG(format("Matched aliases for VarExp '%s': %s", varExpIdent, matched));

                // If there is no match then it isn't an alias referent
                // hence we only care IF it IS an alias referent
                if(matched.length)
                {
                    // Nearest matched alias
                    AliasDeclaration nearestAlias = matched[0];

                    // Now extract the alias's expression and clone it
                    // and make its parent the VariableExpression's
                    // (as it will take its exact place)
                    MCloneable cloneableExpr = cast(MCloneable)nearestAlias.getExpr();
                    assert(cloneableExpr);
                    Expression clonedExpr = cast(Expression)cloneableExpr.clone(varExp.parentOf());

                    // Now, from the current container, replace the
                    // VariableExpression with the cloned expression
                    MStatementReplaceable containerRepl = cast(MStatementReplaceable)container;
                    assert(containerRepl);
                    assert(containerRepl.replace(varExp, clonedExpr));

                }
            }
        }
        else
        {
            DEBUG("Skipping non MStatementSearchable node");
        } 
    }

    /** 
     * Re-writes the types for things such as `size_t`, `ssize_t` and so forth
     *
     * Params:
     *   statement = the `MTypeRewritable` to apply re-writing to
     */
    private void typeRewrite(MTypeRewritable statement)
    {
        /* Applies re-write to Variable's declared type and Function's return type */
        string type = statement.getType();

        /* Only re-write if type alias */
        if(isTypeAlias(type))
        {
            /* Get the concrete type of `type` */
            string concreteType = getConcreteType(type);

            /* Rewrite the type */
            statement.setType(concreteType);
        }
    }

    /** 
     * Performs the replacement of type alieses such as `size_t`, `ssize_t`
     * and so forth with their concrete type
     *
     * Params:
     *   container = the current `Container` being processsed
     *   curStmt = the current `Statement` to consider
     */
    private void doTypeAlias(Container container, Statement curStmt)
    {
        /**
         * Apply type-rewriting to any `MTypeRewritable` AST node
         * (a.k.a. a node which contains a type and can have it set)
         *
         * NOTE: This is just for the "type" fields in AST nodes,
         * we should have some full recursive re-writer.
         *
         * An example of why is for supporting something like:
         *
         *      `sizeof(size_t)` <- currently is not supported by this
         */
        if(cast(MTypeRewritable)curStmt)
        {
            typeRewrite(cast(MTypeRewritable)curStmt);
        }

        /** 
         * Here we will also search for any `IdentExpression`
         * which contains `size_t`, `ssize_t` etc. and replace
         * them
         */
        if(cast(MStatementSearchable)curStmt && cast(MStatementReplaceable)curStmt)
        {
            MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
            IdentExpression[] foundStmts = cast(IdentExpression[])searchableStmt.search(IdentExpression.classinfo);

            // TODO: Implement me
            // gprintln("IdentExpressions found: "~to!(string)(foundStmts));

            /** 
             * Loop through all `IdentExpression`s and find any
             * occurence of `size_t`/`ssize_t` and replace those
             * with the concrete type
             */
            foreach(IdentExpression identExp; foundStmts)
            {
                string identName = identExp.getName();

                /* Determine if this is a type alias? */
                if(isTypeAlias(identName))
                {
                    // Determine the concrete type
                    string concereteType = getConcreteType(identName);
                    DEBUG("Found type alias '"~identName~"' which concretely is '"~concereteType~"'");

                    // Replace with concrete type
                    container.replace(identExp, new IdentExpression(concereteType));
                }
            }
        }
    }

    private IntegerLiteral sizeOf_Literalize(string typeName)
    {
        IntegerLiteral literal = new IntegerLiteral("TODO_LITERAL_GOES_HERESIZEOF_REPLACEMENT", IntegerLiteralEncoding.UNSIGNED_INTEGER);

        // TODO: Via typechecker determine size with a lookup
        Type type = tc.getType(tc.getProgram(), typeName);

        /* Calculated type size */
        ulong typeSize = 0;

        /**
         * Calculate stack array size
         *
         * Algo: `<componentType>.size * stackArraySize`
         */
        if(cast(StackArray)type)
        {
            StackArray stackArrayType = cast(StackArray)type;
            ulong arrayLength = stackArrayType.getAllocatedSize();
            Type componentType = stackArrayType.getComponentType();
            ulong componentTypeSize = 0;
            
            // FIXME: Later, when the Dependency Genrator supports more advanced component types,
            // ... we will need to support this - for now assume that `componentType` is primitive
            if(cast(Number)componentType)
            {
                Number numberType = cast(Number)componentType;
                componentTypeSize = numberType.getSize();
            }

            typeSize = componentTypeSize*arrayLength;
        }
        /**
         * Calculate the size of `Number`-based types
         */
        else if(cast(Number)type)
        {
            Number numberType = cast(Number)type;
            typeSize = numberType.getSize();
        }

        // TODO: We may eed toupdate Type so have bitwidth or only do this
        // for basic types - in which case I guess we should throw an exception
        // here.
        // ulong typeSize = 

        

        /* Update the `Sizeof` kind-of-`IntegerLiteral` with the new size */
        literal.setNumber(to!(string)(typeSize));

        return literal;
    }

    /** 
     * Transforms the type alias into its concrete type.
     *
     * This method incorporates defensive programming in
     * that it will only apply the transformation IF
     * the provided type alias is infact a type alias,
     * otherwise it performs an identity transformation
     * and returns the "alias" untouched.
     *
     * Params:
     *   typeAlias = the potential type alias
     * Returns: the concrete type, or `typeAlias` if
     * not an alias
     */
    private string getConcreteType(string typeAlias)
    {
        /* Check if this is a system type alias? If so, transform */
        if(isSystemType(typeAlias))
        {
            return getSystemType(typeAlias);
        }
        // TODO: Add user-defined type alias support here
        /* Else, return the "alias" untouched */
        else
        {
            return typeAlias;
        }
    }

    /** 
     * Determines if the given type is a type alias.
     *
     * Params:
     *   typeAlias = the type to check
     * Returns: `true` if it is an alias, `false` otherwise
     */
    private bool isTypeAlias(string typeAlias)
    {
        /* If this a system type alias? */
        if(isSystemType(typeAlias))
        {
            return true;
        }
        // TODO: Support for user-defined type aliases
        /* Otherwise, not a type alias */
        else
        {
            return false;
        }
    }

    /** 
     * Determines if the given type is a system type alias
     *
     * Params:
     *   typeAlias = the type to check
     * Returns: `true` if system type alias, `false` otherwise
     */
    private bool isSystemType(string typeAlias)
    {
        /* `size_t`/`ssize_t` system type aliases */
        if(typeAlias == "size_t" || typeAlias == "ssize_t")
        {
            return true;
        }
        /* Else, not a system type alias */
        else
        {
            return false;
        }
    }

    /** 
     * Given a type alias (think `size_t`/`ssize_t` for example) this will
     * look up in the compiler's configuration what that size should be
     * resolved to
     *
     * Params:
     *   typeAlias = the system type alias to lookup
     * Returns: the concrete type
     */
    private string getSystemType(string typeAlias)
    {
        /* Determine machine's width */
        ulong maxWidth = compilerConfig.getConfig("types:max_width").getNumber();

        string maxType;

        if(maxWidth == 1)
        {
            if(typeAlias == "size_t")
            {
                return "ubyte";
            }
            else if(typeAlias == "ssize_t")
            {
                return "byte";
            }
            else
            {
                assert(false);  
            }
        }
        else if(maxWidth == 2)
        {
            if(typeAlias == "size_t")
            {
                return "ushort";
            }
            else if(typeAlias == "ssize_t")
            {
                return "short";
            }
            else
            {
                assert(false);  
            }
        }
        else if(maxWidth == 4)
        {
            if(typeAlias == "size_t")
            {
                return "uint";
            }
            else if(typeAlias == "ssize_t")
            {
                return "int";
            }
            else
            {
                assert(false);  
            }
        }
        else if(maxWidth == 8)
        {
            if(typeAlias == "size_t")
            {
                return "ulong";
            }
            else if(typeAlias == "ssize_t")
            {
                return "long";
            }
            else
            {
                assert(false);  
            }
        }
        else
        {
            assert(false);
        }
    }
}