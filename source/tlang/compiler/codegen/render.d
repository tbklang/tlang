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