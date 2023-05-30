/**
 * TLP reference compiler
 *
 * This is the entry point for the TLP
 * reference compiler.
 */
module tlang.app;

import std.stdio;
import tlang.commandline.args;

void main(string[] args)
{
    writeln("something else\n");

    /* Parse the command-line arguments */
    parseCommandLine(args);
}
