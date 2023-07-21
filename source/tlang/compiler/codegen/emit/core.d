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
import tlang.compiler.codegen.mapper.core : SymbolMapper;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    protected TypeChecker typeChecker;
    protected File file;
    protected CompilerConfiguration config;
    protected SymbolMapper mapper;
    
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

    // TODO: Add allow for custom symbol mapper, use an interface or rather base class mechanism for it
    this(TypeChecker typeChecker, File file, CompilerConfiguration config, SymbolMapper mapper)
    {
        this.typeChecker = typeChecker;

        /* Extract the allocation queue, the code queue */
        initQueue = typeChecker.getInitQueue();
        globalCodeQueue = typeChecker.getGlobalCodeQueue();

        /* Extract the function definitions string-queue mapping */
        functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues();
        gprintln("CodeEmitter: Got number of function defs: "~to!(string)(functionBodyInstrs));
        
        this.file = file;
        this.config = config;

        this.mapper = mapper;
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
     *   customRules = an `Object` to be interpreted by
     * the underlying emitter which can change how certain
     * transformations are done when it is in a certain state
     *
     * Returns: The Instruction emit as a string
     */
    public abstract string transform(Instruction instruction, Object customRules = null);
}