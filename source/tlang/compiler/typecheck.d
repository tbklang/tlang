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

    this(Program program)
    {
        import std.stdio;
        writeln("Got globals: "~to!(string)(program.getAllOf(new Variable(null, null))));
        writeln("Got functions: "~to!(string)(program.getAllOf(new Function(null, null, null, null))));
        writeln("Got classes: "~to!(string)(program.getAllOf(new Clazz(null))));
        
    }
}