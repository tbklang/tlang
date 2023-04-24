module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity;
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
    private Container container;

    this(Container container, TypeChecker tc)
    {
        this.container = container;
        this.tc = tc;
    }

    /** 
     * Analyzes the provided `Container` and searches for any `Macro`-like
     * parse-nodes to process
     */
    public void process()
    {
        /* Get all statements */
        Statement[] stmts = container.getStatements();

        foreach(Statement curStmt; stmts)
        {
            gprintln("MetaProcessor: Examining AST node '"~curStmt.toString()~"'...");

            // TODO: Check for any TypedEntity and look for what their type is, if sizet then replace
            if(cast(TypedEntity)curStmt)
            {
                typeRewrite(cast(TypedEntity)curStmt);
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
        import std.string : cmp;

        string type = statement.getType();
        if(type == "size_t")
        {
            // FIXME: This is an example re-write, it should actually look up the compiler
            // ... config and choose the largest unsigned type from there
            statement.setType("ulong");
        }
    }
}