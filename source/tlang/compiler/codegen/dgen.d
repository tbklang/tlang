module compiler.codegen.dgen;

import compiler.symbols.data;
import compiler.codegen.core;
import gogga;

/**
* This is only for testing, we will definately be using LLVM
* as we want control and no dmd runtime
*/
public class DCodeGenerator : CodeGenerator
{
    this(Module modulle)
    {
        super(modulle);
    }

    public override string build()
    {
        Statement[] statements = modulle.getStatements();

        foreach(Statement statement; statements)
        {
            /* Only for emiitables */
            Emittable emitter = cast(Emittable)statement;

            if(emitter)
            {
                string emittedCode = emitter.emit();
                gprintln("Emitted: "~emittedCode);
            }
            
        }

        return "";
    }
}