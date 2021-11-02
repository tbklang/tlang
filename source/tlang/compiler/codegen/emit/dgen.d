module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;

public final class DCodeEmitter : CodeEmitter
{
    this(TypeChecker typeChecker)
    {
        super(typeChecker);
    }

    public override void emit()
    {
        /* TODO: Implement me */
    }
}