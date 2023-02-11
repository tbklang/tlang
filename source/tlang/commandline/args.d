module tlang.commandline.args;

import jcli.commandgraph.cli;

void parseCommandLine(string[] arguments)
{
    /* Parse the command-line arguments */
    matchAndExecuteAcrossModules!(tlang.commandline.commands)(arguments[1..arguments.length]);
}