module tlang.compiler.codegen.render;

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