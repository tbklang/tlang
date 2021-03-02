module commandline.args;

import jcli;

void parseCommandLine(string[] arguments)
{
    /* Create an instance of the JCLI command-line parser */
    CommandLineInterface!(commandline.commands) commandLineSystem = new CommandLineInterface!(commandline.commands)();

    /* Parse the command-line arguments */
    commandLineSystem.parseAndExecute(arguments);
}