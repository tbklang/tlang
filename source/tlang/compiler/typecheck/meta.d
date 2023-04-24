module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity, Function;
import tlang.compiler.symbols.containers : Container;
import tlang.compiler.symbols.mcro;
// import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.core;
import gogga;

/** 
 * The `MetaProcessor` is used to do a pass over a `Container`
 * to process any macro and macro-like entities
 */
public class MetaProcessor
{
    private TypeChecker tc;

    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    /** 
     * Analyzes the provided `Container` and searches for any `Macro`-like
     * parse-nodes to process
     */
    public void process(Container container)
    {
        /* Get all statements */
        Statement[] stmts = container.getStatements();

        foreach(Statement curStmt; stmts)
        {
            gprintln("MetaProcessor: Examining AST node '"~curStmt.toString()~"'...");

            /**
             * Apply type-rewriting to any TypedEntity
             */
            if(cast(TypedEntity)curStmt)
            {
                typeRewrite(cast(TypedEntity)curStmt);
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
     *   statement = the `TypedEntity` to apply re-writing to
     */
    private void typeRewrite(TypedEntity statement)
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
}