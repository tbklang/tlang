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
import compiler.lexer : Lexer;

@Command("help", "Shows the help screen")
struct helpCommand
{
    /* TODO: Add missing implementation for this */
    void onExecute()
    {

    }
}

/** 
 * Compile the given source file from start to finish
 */
@Command("compile", "Compiles the given file(s)")
struct compileCommand
{
    @CommandPositionalArg(0, "source file", "The source file to compile")
    string sourceFile;

    // @CommandRawListArg
    // string[] d;
    // TODO: Get array

    void onExecute()
    {
        writeln("Compiling source file: "~sourceFile);

        /* TODO: Read file */
        string sourceCode = "";


        beginCompilation([sourceFile]);
    }
}


/**
* Only perform tokenization of the given source files
*/
@Command("lex", "Performs tokenization of the given file(s)")
struct lexCommand
{
    @CommandPositionalArg(0, "source file", "The source file to compile")
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