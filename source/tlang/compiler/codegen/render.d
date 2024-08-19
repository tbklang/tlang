module tlang.compiler.codegen.render;

import tlang.compiler.codegen.instruction : Instruction;

/** 
 * Any instruction which implements
 * this method can have a string
 * representation of itself generated
 * in such a manner as to visually
 * represent the structure of the
 * instruction itself
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
public interface IRenderable
{
    /** 
     * Renders the instruction
     *
     * Returns: the string
     * representation
     */
    public string render();
}

/** 
 * Attempts to render the given
 * instruction. If the instruction
 * supports the `IRenderable`
 * interface then that will be
 * used, otherwise the name of
 * the instruction will be the
 * fallback
 *
 * Params:
 *   instr = the instruction
 * Returns: the representation
 */
public string tryRender(Instruction instr)
{
    IRenderable r_i = cast(IRenderable)instr;

    if(r_i is null)
    {
        return instr.classinfo.name;
    }
    else
    {
        return r_i.render();    
    }
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : LiteralValue;
    import tlang.compiler.codegen.instruction : BinOpInstr;
    import tlang.compiler.symbols.typing.core : Type;
    import tlang.compiler.symbols.check : SymbolType;
}

unittest
{
    LiteralValue lhs = new LiteralValue("1", new Type("int"));
    LiteralValue rhs = new LiteralValue("2", new Type("int"));
    Instruction binOp = new BinOpInstr(lhs, rhs, SymbolType.ADD);

    string s_out = tryRender(binOp);
    // FIXME: Finish this
}