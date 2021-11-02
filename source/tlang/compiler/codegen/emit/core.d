module compiler.codegen.emit.core;

import compiler.symbols.data;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    protected TypeChecker typeChecker;
    
    /**
    * The code queue
    */
    protected SList!(Instruction) codeQueue;
    alias instructions = codeQueue;

    protected File file;

    this(TypeChecker typeChecker, File file)
    {
        this.typeChecker = typeChecker;
        codeQueue = typeChecker.getCodeQueue();
        this.file = file;
    }

    public abstract void emit();
}