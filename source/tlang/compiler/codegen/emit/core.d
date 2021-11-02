module compiler.codegen.emit.core;

import compiler.symbols.data;
import compiler.typecheck.core;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public abstract class CodeEmitter
{
    private TypeChecker typeChecker;
    
    this(TypeChecker typeChecker)
    {
        this.typeChecker = typeChecker;
    }

    public abstract void emit();
}


/**
* Emittable
*
* All structures that can emit code go under here
*
* TODO: Remove this (unused)
*/
public interface Emittable
{
    public string emit();
}