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

import tlang.misc.exceptions : TError;

/**
 * Represents an exception that
 * occurs during meta processing
 */
public class MetaException : TError
{
    this(string msg)
    {
        super(format("MetaException: %s", msg));
    }
}

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

            // Perform alias expression replacement
            doAliasExpression(container, curStmt);

            // Perform replacement of all type alises to concrete types, such as `size_t`
            doTypeAlias(container, curStmt);

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
                                throw new MetaException("The argument to `sizeof` should be a type");
                            }
                        }
                        else
                        {
                            throw new MetaException("To use the `sizeof` macro you require a single argument to be passed to it");   
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

    import tlang.compiler.typecheck.resolution : Resolver;
        
    private AliasDeclaration[] findAliasesFrom(Container from)
    {
        Resolver resolver = tc.getResolver(); // TODO: Remove from here, make a field

        // Predicate to only find aliases (amongst all the different types of statements)
        bool isAliasDecl(Statement stmt) { return cast(AliasDeclaration)stmt !is null; }
        Statement[] declaredAliasesStmts;
        DEBUG("ddd (before): ", from);
        resolver.collectUpwards(from, predicateOf!(isAliasDecl), declaredAliasesStmts);
        return cast(AliasDeclaration[])declaredAliasesStmts;
    }

    private AliasDeclaration findNearestAliasDecl(Container from, string name)
    {
        auto r = tc.getResolver();

        // Predicate to only find aliases (amongst all the different types of statements)
        // and of which match our name
        bool p(Statement stmt)
        {
            auto ad = cast(AliasDeclaration)stmt;
            return ad ? ad.getName() == name : false;
        }

        Statement[] m;
        r.collectUpwards(from, predicateOf!(p), m);
        DEBUG("m: ", m);
        auto ads = cast(AliasDeclaration[])m;

        return ads.length ? ads[0] : null;
    }

    private bool processVarExp(Container c, VariableExpression v_exp)
    {
        // auto p = v_exp.parentOf(); assert(p);
        auto p = c;
        auto p_ident = v_exp.getName();
        auto r = tc.getResolver();
        
        // TODO: Now here sort of lies the problem, `p_ident`
        // could then refer to _anything_, so we really need
        // to check a lot of things:
        //
        // 1. Some entity -> is it a type reference?
        // 2. Some entity -> then is it an alias?
        DEBUG("name reference '", p_ident, "'");
        
        // Type t = tc.getType(c, p_ident);

        // /* If maps to a type? Do nothing */
        // if(t)
        // {
        //     DEBUG("name '", p_ident, "' is type: ", t);
        //     return false;
        // }
        
        /* If it maps to an alias? */
        auto a = findNearestAliasDecl(c, p_ident);
        if(a)
        {
            DEBUG("name '", p_ident, "' refers to an alias: ", a);
            return true;
        }

        // TODO: Okay, but this doesn't feel right,, I should not
        // chekc this here
        return false;
        // throw new MetaException("Eish, this refers to niks");
    }

    private VariableExpression[] getNameReferences(Container c, Expression e)
    {
        // if it is a `variableExpression` then grab its name directly
        // (TODO: See if we should just be checking `IdentExpression` rather)
        auto e_ve = cast(VariableExpression)e;
        if(e_ve)
        {
            return [e_ve];
        }

        // else, try search the expression `e` for `VariableExpression`(s)
        // and collect the names
        auto e_mss = cast(MStatementSearchable)e;
        if(e_mss)
        {
            VariableExpression[] n_s;
            foreach(n; cast(VariableExpression[])e_mss.search(VariableExpression.classinfo))
            {
                n_s ~= getNameReferences(c, n);
            }
            return n_s;
        }

        return [];
    }

    private struct AliasRef
    {
        AliasDeclaration decl;
        VariableExpression reff;
    }

    // find all `VariableExpression` in `e` and then find
    // all alias declarations that exist with names matching
    // `a_i`.getName()
    private AliasRef[] aliasesIn(Container c, Expression e)
    {
        // discover all name references
        auto n_s = getNameReferences(c, e);

        // find all names that refer to aliases declarations
        AliasRef[] a_s;
        auto r = tc.getResolver();
        DEBUG("n_s: ", n_s);
        foreach(n; n_s)
        {
            DEBUG("n: ", n);
            bool p(Statement stmt)
            {
                auto ad = cast(AliasDeclaration)stmt;
                return ad !is null && ad.getName() == n.getName();
            }

            Statement[] m;
            r.collectUpwards(c, predicateOf!(p), m);

            // [0] for assuming first match
            if(m.length)
            {
                a_s ~= AliasRef((cast(AliasDeclaration[])m)[0], n);
            }
        }
        
        DEBUG("a_s: ", a_s);
        return a_s;
    }

    private void proc(Container c, Expression e)
    {
        auto r = tc.getResolver();

        auto a_s = aliasesIn(c, e);
        if(a_s.length == 0)
        {
            DEBUG("no alias refereces found inside of expression: ", e);
            return;
        }

        foreach(a_ref; a_s)
        {
            DEBUG("a_ref: ", a_ref);

            // variable expression doing the referring
            auto a_refFrom = a_ref.reff;
            DEBUG("a_refFrom: ", a_refFrom);

            // the alias referred to
            auto a_i = a_ref.decl;
            DEBUG("a decl: ", a_i);
            auto a_i_e = a_i.getExpr();
            DEBUG("a_i_e: ", a_i_e);
            auto a_i_e_p = a_i_e.parentOf();
            DEBUG("a_i_e_p: ", a_i_e_p);
            assert(a_i_e_p);
            proc(a_i_e_p, a_i_e);
            auto a_i_e_after = a_i.getExpr();
            DEBUG("a_i_e (before): ", a_i_e);
            DEBUG("a_i_e_after (after): ", a_i_e_after);

            // Call positionaliza chech here between `a_i` and `a_refFrom`
            // in order to check use-before-declare
            if(r.isThizAfterThat(a_i, a_refFrom))
            {
                throw new MetaException
                (
                    format
                    (
                        "Usage of an alias %s in %s prior to its declaration",
                        a_i,
                        a_refFrom
                    )
                );
            }

            // TODO: Insert replacement code here
            DEBUG("e: ", e);// FIXME: Yes, we are replacing things WAY to high

            // Clone the `a_i_e_after` and then use that
            // for replacement
            //
            // We clone and set its parent to the same
            // parent at the reference site, i.e. `a_refFrom`'s
            // parent.
            auto a_i_e_after_cl = cast(MCloneable)a_i_e_after; assert(a_i_e_after);
            auto r_s = c.replace(a_refFrom, a_i_e_after_cl.clone(a_refFrom.parentOf()));
            DEBUG("r_s: ", r_s);
        }
    }


    private bool[AliasDeclaration] _ad_vis;

    private void dothing
    (
        Container ctnr,
        VariableExpression target,
        AliasDeclaration ad
    )
    {
        // no entry, make one and set to `true`
        if((ad in _ad_vis) is null)
        {
            _ad_vis[ad] = true;
        }
        // already visited
        else if(_ad_vis[ad])
        {
            return;
        }


        auto a_exp = ad.getExpr();
        DEBUG("--------------");
        DEBUG("ccc reference: ", target);
        DEBUG("ccc a: ", ad);
        DEBUG("ccc a_exp: ", a_exp);
        DEBUG("--------------");
    }

    private void doAliasExpression(Container container, Statement curStmt)
    {
        // Resolver resolver = tc.getResolver(); // TODO: Remove from here, make a field

        // DEBUG(format("doAliasExpression(cntnr:%s, stmt=%s)", container, curStmt));

        // // Find any VariableExpression(s) from curStmt (TODO: should be container or nah?)
        // MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
        // DEBUG("curStmt: ", curStmt);
        // assert(searchableStmt);

        // Expression[] foundStmts = cast(Expression[])searchableStmt.search(Expression.classinfo);
        // foreach(e; foundStmts)
        // {
        //     DEBUG("eb: ", e);
        //     proc(container, e);
        //     DEBUG("ea: ", e);
        // }

        // WARN("Exit");
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
                    container.replace(identExp, new VariableExpression(concereteType));
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
        ulong maxWidth = compilerConfig.getConfig("types:max_width").numeric();

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