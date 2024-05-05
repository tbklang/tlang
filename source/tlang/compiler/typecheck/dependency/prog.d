module tlang.compiler.typecheck.dependency.prog;

import tlang.compiler.typecheck.dependency.core : DNode;
import tlang.compiler.symbols.data : Program;
import std.string : format;

/** 
 * The root dependency node of
 * any compilation unit.
 *
 * Quite notably this contains
 * a `Program` (for meta-data)
 * and is a `DNode` without any
 * `Statement` associated with it.
 */
public final class ProgramDepNode : DNode
{
    private Program program;

    /** 
     * Constructs a new program
     * dependency node
     *
     * Params:
     *   program = the `Program`
     */
    this(Program program)
    {
        // Program is NOT a kind-of Statement
        // yet we must pass SOMETHING
        //
        // TODO: In future make DNode_Base
        // and DNode_Stmt + DNode_Program
        // split
        super(null);

        this.program = program;
        this.name = format("Program Dependency Node [Mods: %d]", getDepCount());
    }

    /** 
     * Obtain the associated program
     *
     * Returns: the `Program`
     */
    public Program getProgram()
    {
        return this.program;
    }
}