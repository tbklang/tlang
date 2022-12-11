module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;
import gogga;
import std.range : walkLength;
import std.string : wrap;

public final class DCodeEmitter : CodeEmitter
{
    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);
    }

    public override void emit()
    {
        // Emit header comment (NOTE: Change this to a useful piece of text)
        emitHeaderComment("Place any extra information by code generator here"); // NOTE: We can pass a string with extra information to it if we want to

        gprintln("Static allocations needed: "~to!(string)(walkLength(initQueue[])));
        emitStaticAllocations(initQueue);

        gprintln("Code emittings needed: "~to!(string)(walkLength(codeQueue[])));
        emitCodeQueue(codeQueue);
    }

    /** 
     * Emits the header comment which contains information about the source
     * file and the generated code file
     *
     * Params:
     *   headerPhrase = Optional additional string information to add to the header comment
     */
    private void emitHeaderComment(string headerPhrase = "")
    {
        // NOTE: We could maybe fetch input fiel info too? Although it would have to be named similiarly in any case
        // so perhaps just appending a `.t` to the module name below would be fine
        string moduleName = typeChecker.getResolver().generateName(typeChecker.getModule(), typeChecker.getModule()); //TODO: Lookup actual module name (I was lazy)
        string outputCFilename = file.name();

        file.write(`/**
 * TLP compiler generated code
 *
 * Module name: `);
        file.writeln(moduleName);
        file.write(" * Output C file: ");
        file.writeln(outputCFilename);

        if(headerPhrase.length)
        {
            file.write(wrap(headerPhrase, 40, " *\n * ", " * "));
        }
        
        file.write(" */\n");
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

    private void emitCodeQueue(SList!(Instruction) codeQueue)
    {
        //TODO: Implement me
        //NOTE: I think that every `Instruction` will need an `emit()` method
        //of which sometimes can be recursive for instructions that are nested

        foreach(Instruction currentInstruction; codeQueue)
        {
            file.writeln(currentInstruction.emit());
        }
    }
}