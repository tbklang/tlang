module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity, Function, FunctionCall, IdentExpression;
import tlang.compiler.symbols.expressions : Expression, IntegerLiteral, IntegerLiteralEncoding;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.containers : Container;
import tlang.compiler.symbols.mcro;
// import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.core;
import gogga;
import std.conv : to;

/** 
 * The `MetaProcessor` is used to do a pass over a `Container`
 * to process any macro and macro-like entities
 */
public class MetaProcessor
{
    private TypeChecker tc;
    private bool isMetaEnabled;

    this(TypeChecker tc, bool isMetaEnabled)
    {
        this.tc = tc;
        this.isMetaEnabled = isMetaEnabled;

        // TODO: Extract the `CompilerConfig` from the `TypeChecker` (which in turn must take it in)
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
            gprintln("MetaProcessor: Examining AST node '"~curStmt.toString()~"'...");

            // Perform replacement of `size_t` with concrete type
            doTypeAlias(container, curStmt);

            
            

            // TODO: Put the two above into one function that does both `size_t` changes (`MTypeRewritable` and `identExpression`-based)

            /**
             * Search for any `sizeof(<ident_type>)` expressions
             * and replace them with a `NumberLiteral`
             */
            if(cast(MStatementSearchable)curStmt && cast(MStatementReplaceable)curStmt)
            {
                MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
                Statement[] foundStmts = searchableStmt.search(FunctionCall.classinfo);
                gprintln("Nah fr");

                foreach(Statement curFoundStmt; foundStmts)
                {
                    FunctionCall curFuncCall = cast(FunctionCall)curFoundStmt;

                    if(curFuncCall.getName() == "sizeof")
                    {
                        gprintln("Elo");
                        Expression[] arguments = curFuncCall.getCallArguments();
                        if(arguments.length == 1)
                        {
                            IdentExpression potentialIdentExp = cast(IdentExpression)arguments[0];
                            if(potentialIdentExp)
                            {
                                string typeName = potentialIdentExp.getName();
                                IntegerLiteral replacementStmt = sizeOf_Literalize(typeName);
                                gprintln("sizeof: Replace '"~curFoundStmt.toString()~"' with '"~replacementStmt.toString()~"'");

                                /* Traverse down from the `Container` we are process()'ing and apply the replacement */
                                MStatementReplaceable containerRepl = cast(MStatementReplaceable)container;
                                containerRepl.replace(curFoundStmt, replacementStmt);
                            }
                            else
                            {
                                // TODO: Throw an exception here that an ident_type should be present as the argument
                                gprintln("The argument to `sizeof` should be an ident", DebugType.ERROR);
                            }
                        }
                        else
                        {
                            // TODO: Throw an exception here as only 1 argument is allowed
                            gprintln("To use the `sizeof` macro you require a single argument to be passed to it", DebugType.ERROR);
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
        if(type == "size_t")
        {
            // FIXME: This is an example re-write, it should actually look up the compiler
            // ... config and choose the largest unsigned type from there
            statement.setType("ulong");
        }
        else if(type == "ssize_t")
        {
            // FIXME: This is an example re-write, it should actually look up the compiler
            // ... config and choose the largest unsigned type from there
            statement.setType("long");
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
            foreach(IdentExpression identExp; foundStmts)
            {
                gprintln(identExp);
                if(identExp.getName() == "size_t")
                {
                    gprintln("Found type alias");

                    // TODO: Testing code below
                    // TODO: Replace with correct compiler configured type
                    container.replace(identExp, new IdentExpression("uint"));
                }
            }
        }
    }

    private IntegerLiteral sizeOf_Literalize(string typeName)
    {
        IntegerLiteral literal = new IntegerLiteral("TODO_LITERAL_GOES_HERESIZEOF_REPLACEMENT", IntegerLiteralEncoding.UNSIGNED_INTEGER);

        // TODO: Via typechecker determine size with a lookup
        Type type = tc.getType(tc.getModule(), typeName);

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
}