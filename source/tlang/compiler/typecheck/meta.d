module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity, Function;
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

            /**
             * Apply type-rewriting to any `MTypeRewritable` AST node
             * (a.k.a. a node which contains a type and can have it set)
             */
            if(cast(MTypeRewritable)curStmt)
            {
                typeRewrite(cast(MTypeRewritable)curStmt);
            }

            /**
             * Search for any `sizeof(<ident_type>)` expressions
             * and replace them with a `NumberLiteral`
             */
            if(cast(MStatementSearchable)curStmt && cast(MStatementReplaceable)curStmt)
            {
                MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
                Statement[] foundStmts = searchableStmt.search(Repr.classinfo);
            }


            /**
             * TODO: Add support for `sizeof` statement too
             *
             * To do this we must consider where `Expression` can occur:
             * Function arguments, Variable assignments
             *
             * Such that we can apply fixups there
             */
            // expressionSearch();
            if(cast(MStatementSearchable)curStmt && cast(MStatementReplaceable)curStmt)
            {
                // TOOD: Add replacement here
                gprintln("Found a searchable and replaceable '"~curStmt.toString()~"'");

                /** 
                 * Searching for AST nodes of a given type
                 */
                MStatementSearchable searchableStmt = cast(MStatementSearchable)curStmt;
                Statement[] foundStmts = searchableStmt.search(Repr.classinfo);
                gprintln("Repr Search: "~to!(string)(foundStmts));
                gprintln("isRepr?: "~to!(string)(cast(Repr)foundStmts[0] !is null));

                /** 
                 * Replacing an AST node with another
                 */
                MStatementReplaceable replStmt = cast(MStatementReplaceable)curStmt;
                import tlang.compiler.symbols.expressions : IntegerLiteral, IntegerLiteralEncoding;
                bool replStatus = replStmt.replace(foundStmts[0], new IntegerLiteral("69420", IntegerLiteralEncoding.SIGNED_INTEGER));
                gprintln("Replacement worked?: "~to!(string)(replStatus));
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

    private void sizeOf_Literalize(Sizeof sizeofNumber)
    {
        // TODO: Via typechecker determine size with a lookup
        Type type = tc.getType(tc.getModule(), sizeofNumber.getType());

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

        // TODO: We may eed toupdate Type so have bitwidth or only do this
        // for basic types - in which case I guess we should throw an exception
        // here.
        // ulong typeSize = 

        /* Update the `Sizeof` kind-of-`IntegerLiteral` with the new size */
        sizeofNumber.setNumber(to!(string)(typeSize));
    }
}