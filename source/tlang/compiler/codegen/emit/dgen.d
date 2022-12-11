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
import std.range : walkLength;

public final class DCodeEmitter : CodeEmitter
{
    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);
    }

    public override void emit()
    {
        // Emit header comment
        emitHeaderComment(); // NOTE: We can pass a string with extra information to it if we want to

        gprintln("Static allocations needed: "~to!(string)(walkLength(initQueue[])));
        emitStaticAllocations(initQueue);

        gprintln("Code emittings needed: "~to!(string)(walkLength(codeQueue[])));
    }

    private void emitHeaderComment(string headerPhrase = "")
    {
        string moduleName = typeChecker.getResolver().generateName(typeChecker.getModule(), typeChecker.getModule()); //TODO: Lookup actual module name (I was lazy)
        string outputCFilename = file.name();

        file.write(`
/**
 * TLP compiler generated code
 *
 * Module name: `);
        file.writeln(moduleName);
        file.write(" * Output C file: ");
        file.writeln(outputCFilename);

        if(headerPhrase.length)
        {
            file.writeln(" *\n * "~headerPhrase);
        }
        
        file.writeln(" */");
    }

    /** 
     * Emits the static allocations provided
     *
     * Params:
     *   initQueue = The allocation queue to emit static allocations from
     */
    private void emitStaticAllocations(SList!(Instruction) initQueue)
    {

    }
}