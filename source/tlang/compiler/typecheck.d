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
        writeln("Got globals: "~to!(string)(program.getGlobals()));
    }
}