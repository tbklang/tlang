module compiler.compiler;

import gogga;
import std.conv : to;
import compiler.lexer;

void beginCompilation(string[] sourceFiles)
{
    /* TODO: Begin compilation process, take in data here */
    gprintln("Compiling files "~to!(string)(sourceFiles)~" ...");

    Lexer[] lexers;
    foreach(string sourceFile; sourceFiles)
    {
        gprintln("Performing tokenization on '"~sourceFile~"' ...");

        /* TODO: Open source file */
        string sourceCode = "hello \"world\";";
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        currentLexer.performLex();
        
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    }
}