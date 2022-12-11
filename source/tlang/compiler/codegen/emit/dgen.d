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
import std.process : spawnProcess, Pid, ProcessException, wait;

public final class DCodeEmitter : CodeEmitter
{
    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);
    }

    public override void finalize()
    {
        try
        {
            //NOTE: Change to system compiler (maybe, we need to choose a good C compiler)
            Pid ccPID = spawnProcess(["gcc", "-o", "tlang.out", file.name()]);

            //NOTE: Case where it exited and Pid now inavlid (if it happens it would throw processexception surely)?
            int code = wait(ccPID);
            gprintln(code);

            if(code)
            {
                //NOTE: Make this a TLang exception
                throw new Exception("The CC exited with a non-zero exit code");
            }
        }
        catch(ProcessException e)
        {
            gprintln("NOTE: Case where it exited and Pid now inavlid (if it happens it would throw processexception surely)?", DebugType.ERROR);
            assert(false);

        }
    }

    public override void emit()
    {
        // Emit header comment (NOTE: Change this to a useful piece of text)
        emitHeaderComment("Place any extra information by code generator here"); // NOTE: We can pass a string with extra information to it if we want to

        gprintln("Static allocations needed: "~to!(string)(walkLength(initQueue[])));
        emitStaticAllocations(initQueue);

        gprintln("Code emittings needed: "~to!(string)(walkLength(codeQueue[])));
        emitCodeQueue(codeQueue);

        //TODO: Emit function definitions

        //TODO: Emit main (entry point)
        emitEntryPoint();
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

    private void emitEntryPoint()
    {
        //TODO: Implement me

        file.writeln(`
int main()
{
    return 0;
}`);
    }
}