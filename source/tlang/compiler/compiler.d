module compiler.compiler;

import gogga;
import std.conv : to;
import compiler.lexer;
import std.stdio : File;
import compiler.parsing.core;
import compiler.symbols.check;
import compiler.symbols.data;
import compiler.typecheck.core;
import compiler.typecheck.exceptions;
import core.stdc.stdlib;
import compiler.codegen.emit.core;
import compiler.codegen.emit.dgen;

void beginCompilation(string[] sourceFiles)
{
    /* TODO: Begin compilation process, take in data here */
    gprintln("Compiling files "~to!(string)(sourceFiles)~" ...");

    Lexer[] lexers;
    foreach(string sourceFile; sourceFiles)
    {
        gprintln("Reading source file '"~sourceFile~"' ...");
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

        gprintln("Performing tokenization on '"~sourceFile~"' ...");

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        bool status = currentLexer.performLex();
        if(!status)
        {
            return;
        }
        
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));

        gprintln("Parsing tokens...");
        Parser parser = new Parser(currentLexer.getTokens());
        Module modulle;
        
        import misc.exceptions;

        try
        {
            modulle = parser.parse();
        }
        catch(TError e)
        {
            gprintln(e.msg, DebugType.ERROR);
            exit(0); /* TODO: Exit code */  /* TODO: Version that returns or asserts for unit tests */
        }
        
        

        gprintln("Type checking and symbol resolution...");
        try
        {
            TypeChecker typeChecker = new TypeChecker(modulle);
            typeChecker.beginCheck();

            CodeEmitter emitter = new DCodeEmitter(typeChecker);
            emitter.emit();
        }
        // catch(CollidingNameException e)
        // {
        //     gprintln(e.msg, DebugType.ERROR);
        //     //gprintln("Stack trace:\n"~to!(string)(e.info));
        // }
        catch(TypeCheckerException e)
        {
            gprintln(e.msg, DebugType.ERROR);
            exit(0);
        }

        

        // import compiler.codegen.core;
        // CodeGenerator codegen = new DCodeGenerator(modulle);
        // codegen.build();
        
        // typeChecker.check();
    }
}