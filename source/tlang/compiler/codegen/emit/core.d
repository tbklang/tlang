module tlang.compiler.codegen.emit.core;

import tlang.compiler.symbols.data;
import tlang.compiler.typecheck.core;
import std.container.slist : SList;
import tlang.compiler.codegen.instruction;
import std.stdio;
import std.file;
import tlang.compiler.codegen.instruction : Instruction;
import std.range : walkLength;
import gogga;
import std.conv : to;
import tlang.compiler.configuration : CompilerConfiguration;

import tlang.misc.exceptions : TError;

/** 
 * The general exception type for any
 * and all code emitter related errors.
 *
 * An implementation of the `CodeEmitter`
 * class should sub-class this one when
 * throwing emitter-specific exceptions
 */
public abstract class CodeEmitError : TError
{
    this(string m)
    {
        super("CodeEmit error: "~m);
    }
}

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    protected TypeChecker typeChecker;
    protected File file;
    protected CompilerConfiguration config;
    
    /** 
     * The selected queue is the queue to be used
     * when using the cursor instructions such as
     * `nextInstruction()`, `previousInstruction()`
     * etc.
     */
    private Instruction[] selectedQueue;

    public enum QueueType
    {
        ALLOC_QUEUE,
        GLOBALS_QUEUE,
        FUNCTION_DEF_QUEUE
    }

    private ulong queueCursor = 0;

    public final void selectQueue(Module owner, QueueType queueType, string funcDefName = "")
    {
        // Move the cursor back to the starting position
        resetCursor();

        if(queueType == QueueType.ALLOC_QUEUE)
        {
            selectedQueue = this.typeChecker.getInitQueue(owner);
        }
        else if(queueType == QueueType.GLOBALS_QUEUE)
        {
            selectedQueue = this.typeChecker.getGlobalCodeQueue(owner);
        }
        else
        {
            //TODO: Ensure valid name by lookup via tc

            // Get the function definitions of the current module
            functionBodyInstrs = this.typeChecker.getFunctionBodyCodeQueues(owner);

            // Select the function definition by name from it
            // and make that the current code queue
            selectedQueue = functionBodyInstrs[funcDefName];
        }
    }

    public final void resetCursor()
    {
        queueCursor = 0;
    }

    public final void nextInstruction()
    {
        // TODO: Sanity check on length

        queueCursor++;
    }

    public final void previousInstruction()
    {
        // TODO: Sanity check on lenght

        queueCursor--;
    }

    public final bool hasInstructions()
    {
        return queueCursor < selectedQueue.length;
    }

    public final Instruction getCurrentInstruction()
    {
        return selectedQueue[queueCursor];
    }

    public final ulong getCursor()
    {
        return queueCursor;
    }

    public final ulong getSelectedQueueLength()
    {
        return selectedQueue.length;
    }
    
    public final ulong getQueueLength()
    {
        return selectedQueue.length;
    }
    
    /**
    * Required queues (maps to them)
    */
    private Instruction[][string] functionBodyInstrs;

    public final ulong getFunctionDefinitionsCount(Module owner)
    {
        // Get the function definitions of the current module
        functionBodyInstrs = this.typeChecker.getFunctionBodyCodeQueues(owner);

        return functionBodyInstrs.keys().length;
    }

    public final string[] getFunctionDefinitionNames(Module owner)
    {
        // Get the function definitions of the current module
        functionBodyInstrs = this.typeChecker.getFunctionBodyCodeQueues(owner);

        return functionBodyInstrs.keys();
    }

    this(TypeChecker typeChecker, File file, CompilerConfiguration config)
    {
        this.typeChecker = typeChecker;
        this.file = file;
        this.config = config;
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