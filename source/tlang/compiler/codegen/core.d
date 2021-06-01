module compiler.codegen.core;

import compiler.symbols.data;

/**
* TODO: Perhaps have an interface that can emit(Context/Parent, Statement)
*/

/* TODO: Module linking (general overhaul required) */

public class CodeGenerator
{
    /* The Module */
    Module modulle;

    this(Module modulle)
    {
        this.modulle = modulle;
    }
}

public import compiler.codegen.dgen;

/**
* Emittable
*
* All structures that can emit code go under here
*/
public interface Emittable
{
    public string emit();
}