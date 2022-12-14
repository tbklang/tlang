/**
 * TLP reference compiler
 *
 * This is the entry point for the TLP
 * reference compiler.
 */
module tlang;

import std.stdio;
import commandline.args;

void main(string[] args)
{
	/* TODO: Replace with something else */
    writeln("tlang NO_PUBLISH_RELEASE\n");

    /* Parse the command-line arguments */
    parseCommandLine(args);
}
