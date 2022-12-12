module compiler.codegen.emit.core;

import compiler.symbols.data;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import compiler.codegen.instruction : Instruction;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    protected TypeChecker typeChecker;
    
    /**
    * Required queues
    */
    protected SList!(Instruction) initQueue;
    protected SList!(Instruction) codeQueue;

    alias instructions = codeQueue;

    protected File file;

    this(TypeChecker typeChecker, File file)
    {
        this.typeChecker = typeChecker;

        /* Extract the allocation queue, the code queue */
        initQueue = typeChecker.getInitQueue();
        codeQueue = typeChecker.getCodeQueue();
        


        this.file = file;
    }

    /** 
     * Begins the emit process
     */
    public abstract void emit();

    /** 
     * Finalizes the emitting process (only
     * to be called after the `emit()` finishes)
     */
    public abstract void finalize();

    /** 
     * Transforms or emits a single Instruction
     * and returns the transformation
     *
     * Params:
     *   instruction = The Instruction to transform/emit
     * Returns: The Instruction emit as a string
     */
    public abstract string transform(Instruction instruction);
}