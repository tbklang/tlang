/** 
 * This provides all the routines to be used
 * when user-oriented logging is to be done.
 *
 * User-oriented logging is defined as anything
 * that would be important to let the user
 * know about, hence debugging logs are not
 * considered patt of this definition.
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.misc.messaging;

// FIXME: Make use of dlog and a custom transformer
import dlog.basic : Level, FileHandler;

import std.array : join;
import std.conv : to;
import std.stdio : stderr;
import std.string : format;

import tlang.compiler.symbols.data : Entity, Module;
import tlang.compiler.typecheck.resolution : Resolver;

byte[] WARN_COLOR = [27, '[', '3', '3', 'm'];
byte[] ERROR_COLOR = [27, '[', '3', '1', 'm'];
byte[] INFO_COLOR = [27, '[', '3', '2', 'm'];
byte[] TIP_COLOR = [27, '[', '3', '6', 'm'];

byte[] RESET = [27, '[', 'm'];

// TODO: Move into niknaks
// Generates short name of the classinfo.name
// such that x.y.z -> z
private string shortName(TypeInfo_Class ti)
{
    import std.string : split;
    string shortName = ti.name.split(".")[$-1];
    return shortName;
}

import niknaks.meta : isClassType;
private string shortName(T)(T item)
if
(
    isClassType!(T)()
)
{
    return shortName(T.classinfo);
}

private string genToString(T)(T item, Resolver r = null)
{
    import std.traits : isAssignable, isIntegral;
    static if(__traits(isSame, T, string))
    {
        return item;
    }
    // Transform any entity into the following shortstring:
    //
    // Entity "x" -> "x" in <module of x>
    else static if(isAssignable!(Entity, T))
    {
        pragma(msg, "ENtity-based formatting active");

        string entType = shortName(item);

        // FIXME: Fix types without parenting
        // assert(item.parentOf());
        if(item.parentOf())
        {
            Module inMod = cast(Module)Resolver.findContainerOfType(Module.classinfo, item);
            return format("%s '%s' in module %s", entType, item.getName(), inMod.getName());
        }
        else
        {
            return format("%s '%s'", entType, item.getName());
        }
    }
    else static if(isIntegral!(T))
    {
        return format("%s", item);
    }
    // TODO: Handle expressions here with a sort of IASTRender
    // and ASTRenderer
    
    // TODO: SymbolType support
    // TODO: Token support

    // TODO: Add array support (it should make them appear as {1, 2, ...})
    else
    {
        return format("'%s'", to!(string)(item));
    }
}

// Given any arguments this makes a string with
// formatting automatically applied to arguments
// of interest
public string makeMessage(T...)(T args, Resolver r = null)
{
    string[] s_a;
    static foreach(a; args)
    {
        s_a ~= genToString(a, r);
    }
    string s = join(s_a, " ");
    return s;
}


// Use this for messages that are warnings
public void warn(T...)(T args, string subSystem = "")
{
    byte[] b;
    b ~= WARN_COLOR;
    b ~= "Warning ";
    b ~= RESET;
    b ~= makeMessage(args);
    b ~= "\n";

    stderr.rawWrite(b);
}

// Use this for any messages that are informative
// tips
public void tip(T...)(T args, string subSystem = "")
{
    byte[] b;
    b ~= TIP_COLOR;
    b ~= "Tip ";
    b ~= RESET;
    b ~= makeMessage(args);
    b ~= "\n";

    stderr.rawWrite(b);
}

// Use this for any messages indicating an error
public void error(T...)(T args, string subSystem = "")
{
    byte[] b;
    b ~= ERROR_COLOR;
    b ~= "Error ";
    b ~= RESET;
    b ~= makeMessage(args);
    b ~= "\n";

    stderr.rawWrite(b);
}

// Use this for any messages indicating an informative
// message
public void info(T...)(T args, string subSystem = "")
{
    byte[] b;
    b ~= INFO_COLOR;
    b ~= "Info ";
    b ~= RESET;
    b ~= makeMessage(args);
    b ~= "\n";

    stderr.rawWrite(b);
}