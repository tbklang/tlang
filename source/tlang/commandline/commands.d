/**
 * Commands
 *
 * All command-line arguments and their impementations
 */

module commandline.commands;

import jcli;
import std.stdio;
import compiler.compiler : beginCompilation;
import std.exception : ErrnoException;
import compiler.lexer : Lexer, Token;
import compiler.parsing.core : Parser;
import compiler.typecheck.core : TypeChecker;

//TODO: Re-order the definitions below so that they appear with compile first, then lex, parse, ..., help

/** 
 * Compile the given source file from start to finish
 */
@Command("compile", "Compiles the given file(s)")
struct compileCommand
{
    @ArgPositional("source file", "The source file to compile")
    string sourceFile;

    // @CommandRawListArg
    // string[] d;
    // TODO: Get array

    void onExecute()
    {
        writeln("Compiling source file: "~sourceFile);
        beginCompilation([sourceFile]);
    }
}

/**
* Only perform tokenization of the given source files
*/
@Command("lex", "Performs tokenization of the given file(s)")
struct lexCommand
{
    @ArgPositional("source file", "The source file to lex")
    string sourceFile;

    void onExecute()
    {
        writeln("Performing tokenization on file: "~sourceFile);

        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Lexer lexer = new Lexer(sourceText);
            if(lexer.performLex())
            {
                writeln("=== Tokens ===\n");
                writeln(lexer.getTokens());
            }
            else
            {
                /* TODO: Is the lexer.performLex() return value used? */
                writeln("There was an error whilst performing tokenization");
            }
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
        }
    }
}

@Command("syntaxcheck", "Check the syntax of the program")
struct parseCommand
{
    @ArgPositional("source file", "The source file to check syntax of")
    string sourceFile;

    /* TODO: Add missing implementation for this */
    void onExecute()
    {
        // TODO: Add call to typechecker here

        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Lexer lexer = new Lexer(sourceText);
            if(lexer.performLex())
            {
                Token[] tokens = lexer.getTokens();
                writeln("=== Tokens ===\n");
                writeln(tokens);

                // TODO: Catch exception
                Parser parser = new Parser(tokens);
                // TODO: Do something with the returned module
                auto modulel = parser.parse();
            }
            else
            {
                /* TODO: Is the lexer.performLex() return value used? */
                writeln("There was an error whilst performing tokenization");
            }
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
        }
    }
}

@Command("typecheck", "Perform typechecking on the program")
struct typecheckCommand
{
    @ArgPositional("source file", "The source file to typecheck")
    string sourceFile;

    /* TODO: Add missing implementation for this */
    void onExecute()
    {
        // TODO: Add call to typechecker here
        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Lexer lexer = new Lexer(sourceText);
            if(lexer.performLex())
            {
                Token[] tokens = lexer.getTokens();
                writeln("=== Tokens ===\n");
                writeln(tokens);

                // TODO: Catch exception
                Parser parser = new Parser(tokens);
                // TODO: Do something with the returned module
                auto modulel = parser.parse();

                //TODO: collect results here
                //TODO: catch exceptions
                TypeChecker typeChecker = new TypeChecker(modulel);
                typeChecker.beginCheck();
            }
            else
            {
                /* TODO: Is the lexer.performLex() return value used? */
                writeln("There was an error whilst performing tokenization");
            }
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
        }
    }
}

// @Command("emit", "Perform emitting on the program")
// struct emitCommand
// {
//     @ArgPositional("source file", "The source file to emit")
//     string sourceFile;

//     /* TODO: Add missing implementation for this */
//     void onExecute()
//     {
//         // TODO: Add call to typechecker here
//         try
//         {
//             /* Read the source file's data */
//             File file;
//             file.open(sourceFile, "r");
//             ulong fSize = file.size();
//             byte[] data;
//             data.length = fSize;
//             data = file.rawRead(data);
//             string sourceText = cast(string)data;
//             file.close();

//             /* Begin lexing process */
//             Lexer lexer = new Lexer(sourceText);
//             if(lexer.performLex())
//             {
//                 Token[] tokens = lexer.getTokens();
//                 writeln("=== Tokens ===\n");
//                 writeln(tokens);

//                 // TODO: Catch exception
//                 Parser parser = new Parser(tokens);
//                 // TODO: Do something with the returned module
//                 auto modulel = parser.parse();

//                 //TODO: collect results here
//                 //TODO: catch exceptions
//                 TypeChecker typeChecker = new TypeChecker(modulel);
//                 typeChecker.beginCheck();

//                 //TODO: emit is basically full cpmpile or nah? we should write emit to stdout actually
//                 //or nah?
//             }
//             else
//             {
//                 /* TODO: Is the lexer.performLex() return value used? */
//                 writeln("There was an error whilst performing tokenization");
//             }
//         }
//         catch(ErrnoException e)
//         {
//             /* TODO: Use gogga error */
//             writeln("Could not open source file "~sourceFile);
//         }
//     }
// }

@Command("help", "Shows the help screen")
struct helpCommand
{
    /* TODO: Add missing implementation for this */
    void onExecute()
    {
        /* TODO: We want to show the commands list, not a seperate help command */
    }
}