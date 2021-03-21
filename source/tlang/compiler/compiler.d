module compiler.compiler;

import gogga;
import std.conv : to;
import compiler.lexer;
import std.stdio : File;
import compiler.parser;
import compiler.symbols;
import compiler.typecheck;

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
        currentLexer.performLex();
        
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));

        gprintln("Parsing tokens...");
        Parser parser = new Parser(currentLexer.getTokens());
        Program program = parser.parse();

        gprintln("Type checking and symbol resolution...");
        TypeChecker typeChecker = new TypeChecker(program);
    }
}