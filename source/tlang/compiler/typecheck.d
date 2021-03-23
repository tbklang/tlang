module compiler.typecheck;

import compiler.symbols;
import std.conv : to;

/**
* Used to run through generated IR
* from parsing and do type-checking
* and name-resolution
*/
public final class TypeChecker
{
    private Program program;

    this(Program program)
    {
        this.program = program;

        import std.stdio;
        writeln("Got globals: "~to!(string)(program.getAllOf(new Variable(null, null))));
        writeln("Got functions: "~to!(string)(program.getAllOf(new Function(null, null, null, null))));
        writeln("Got classes: "~to!(string)(program.getAllOf(new Clazz(null))));
        
    }

    /**
    * This function will walk, recursively, through
    * each Statement at the top-level and generate
    * names of declared items in a global array
    *
    * This is top-level, iterative then recursive within
    * each iteration
    *
    * The point of this is to know of all symbols
    * that exist so that we can do a second pass
    * and see if symbols in use (declaration does
    * not count as "use") are infact valid references
    */
    public void nameResolution()
    {
        string[] names;

        foreach(Statement statement; program.getAllOf(new Statement()))
        {
            /* TODO: Add container name */
            // names ~= 
            // string[] receivedNameSet = resolveNames(statement);
        }
    }

    private string[] resolveNames(Statement statement)
    {
        // string containerName
        return null;
    }


    public void check()
    {
        checkDuplicateTopLevel();

        /* TODO: Process globals */
        /* TODO: Process classes */
        /* TODO: Process functions */
    }

    

    /**
    * Ensures that at the top-level there are no duplicate names
    */
    private bool checkDuplicateTopLevel()
    {
        import misc.utils;
        import compiler.parser : Parser;

        /* List of names travsersed so far */
        string[] names;

        /* Add all global variables */
        foreach(Variable variable; program.getAllOf(new Variable(null, null)))
        {
            string name = variable.getName();

            if(isPresent(names, name))
            {
                Parser.expect("Bruh duplicate var"~name);
            }
            else
            {
                names ~= variable.getName();
            }
        }

        return true;
    }
}