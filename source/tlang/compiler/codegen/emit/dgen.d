module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;
import compiler.codegen.emit.dgenregs;
import gogga;

public final class DCodeEmitter : CodeEmitter
{
    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);
    }

    public override void emit()
    {
        // TODO: Implement me
    }
}