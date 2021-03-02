/**
* Commands
*
* All command-line arguments and their impementations
*/

module commandline.commands;

import jcli;
import std.stdio;

@Command("help", "Shows the help screen")
struct helpCommand
{
    void onExecute()
    {

    }
}

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
    }
}