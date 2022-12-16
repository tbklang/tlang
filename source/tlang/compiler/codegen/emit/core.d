module compiler.codegen.emit.core;

import compiler.symbols.data;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import compiler.codegen.instruction : Instruction;
import std.range : walkLength;
import gogga;
import std.conv : to;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    protected TypeChecker typeChecker;
    protected File file;
    
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

    public final void selectQueue(QueueType queueType, string funcDefName = "")
    {
        // Move the cursor back to the starting position
        resetCursor();

        if(queueType == QueueType.ALLOC_QUEUE)
        {
            selectedQueue = initQueue;
        }
        else if(queueType == QueueType.GLOBALS_QUEUE)
        {
            selectedQueue = globalCodeQueue;
        }
        else
        {
            //TODO: Ensure valid name by lookup via tc

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
    * Required queues
    */
    private Instruction[] initQueue;
    private Instruction[] globalCodeQueue;

    /**
    * Required queues (maps to them)
    */
    private Instruction[][string] functionBodyInstrs;

    public final ulong getFunctionDefinitionsCount()
    {
        return functionBodyInstrs.keys().length;
    }

    public final string[] getFunctionDefinitionNames()
    {
        return functionBodyInstrs.keys();
    }

    this(TypeChecker typeChecker, File file)
    {
        this.typeChecker = typeChecker;

        /* Extract the allocation queue, the code queue */
        initQueue = typeChecker.getInitQueue();
        globalCodeQueue = typeChecker.getGlobalCodeQueue();

        /* Extract the function definitions string-queue mapping */
        functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues();
        gprintln("CodeEmitter: Got number of function defs: "~to!(string)(functionBodyInstrs));
        
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