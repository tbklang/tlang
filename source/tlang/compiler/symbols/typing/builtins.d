/**
 * Routines for determining, based on an input strung,
 * the built-in type that is associated with that
 * identifier/name
 */
module tlang.compiler.symbols.typing.builtins;

import tlang.compiler.symbols.typing.core;
import std.string : cmp, indexOf, lastIndexOf;
import tlang.misc.logging;
import tlang.compiler.typecheck.core;
import std.conv : to;
import tlang.compiler.symbols.data : Container;
import std.string : format, split, join;

/** 
 * Tries to resolve the type string
 * as a primitive type
 *
 * Params:
 *   typeString = the type string
 * to attempt resolution of
 *   primTypeOut = the found primitive
 * type (if any)
 * Returns: `true` if the type string
 * referred solely to a primitive
 * type, `false` otherwise
 */
private bool getPrimitiveType(string typeString, ref Type primTypeOut)
{
    /* `int`, signed (2-complement) */
    if(cmp(typeString, "int") == 0)
    {
        primTypeOut = new Integer("int", 4, true);
        return true;
    }
    /* `uint` unsigned */
    else if(cmp(typeString, "uint") == 0)
    {
        primTypeOut = new Integer("uint", 4, false);
        return true;
    }
    /* `long`, signed (2-complement) */
    else if(cmp(typeString, "long") == 0)
    {
        primTypeOut = new Integer("long", 8, true);
        return true;
    }
    /* `ulong` unsigned */
    else if(cmp(typeString, "ulong") == 0)
    {
        primTypeOut = new Integer("ulong", 8, false);
        return true;
    }
    /* `short`, signed (2-complement) */
    else if(cmp(typeString, "short") == 0)
    {
        primTypeOut = new Integer("short", 2, true);
        return true;
    }
    /* `ushort` unsigned */
    else if(cmp(typeString, "ushort") == 0)
    {
        primTypeOut = new Integer("ushort", 2, false);
        return true;
    }
    /* `byte`, signed (2-complement) */
    else if(cmp(typeString, "byte") == 0)
    {
        primTypeOut = new Integer("byte", 1, true);
        return true;
    }
    /* `ubyte` unsigned */
    else if(cmp(typeString, "ubyte") == 0)
    {
        primTypeOut = new Integer("ubyte", 1, false);
        return true;
    }
    /* `void` */
    else if (cmp(typeString, "void") == 0)
    {
        primTypeOut = new Void();
        return true;
    }
    /* TODO: Decide on these (floats and doubles need to be specced out) */
    /* `float` */
    else if(cmp(typeString, "float") == 0)
    {
        primTypeOut = new Float("float", 4);
        return true;
    }
    /* `double` */
    else if(cmp(typeString, "double") == 0)
    {
        primTypeOut = new Float("double", 8);
        return true;
    }
    /* TODO: What do we want? Char enforcement is kind of cringe I guess */
    else if(cmp(typeString, "char") == 0)
    {
        primTypeOut = new Integer("ubyte", 1, false);
        return true;
    }
    else
    {
        WARN(format("No, '%s' is not a primitive type", typeString));
        return false;
    }
}

/**
* TODO: We should write spec here like I want int and stuff of proper size so imma hard code em
* no machine is good if int is not 4, as in imagine short being max addressable unit
* like no, fuck that (and then short=int=long, no , that is shit AND is NOT WHAT TLANG aims for)
*/
// TODO: Rename this because it isn't just buuiltin types
/** 
 * Creates a new instance of the type that is detected via
 * the given string. Only for built-in types.
 *
 * Example, if given `"int"` then you will get an instance
 * of `new Integer("int", 4, true)`
 *
 * Params:
 *   tc = the associated `TypeChecker` required for lookups
 *   container = the container to do any searches from
 *   typeString = the type string to test
 * Returns: the `Type` found, if not found then `null`
 */
public Type getBuiltInType(TypeChecker tc, Container container, string typeString)
{
    DEBUG("getBuiltInType("~typeString~")");

    Type typeOut;

    /* Primitive data types */
    if(getPrimitiveType(typeString, typeOut))
    {
        return typeOut;
    }
    /* Primitive data types (long form) */
    else if(getLongFormPrimitiveType(tc, container, typeString, typeOut))
    {
        DEBUG(format("Got long form primitive of '%s' from '%s'", typeOut, typeString));
        return typeOut;
    }
    /* A module */
    else if(cmp(typeString, "module") == 0)
    {
        return new ModuleType();
    }
    /* Stack-based array handling `<componentType>[<number>]` */
    else if(isStackArray(typeString))
    {
        // TODO: Construct this by dissecting `typeString`
        StackArray stackArray;

        // Find the last occuring `[`
        long lastOBracketPos = lastIndexOf(typeString, "[");
        assert(lastOBracketPos > -1);

        // Find the component type (everything before `lastOBracketPos`)
        string componentTypeString = typeString[0..lastOBracketPos];
        DEBUG("StackArray (component type): "~componentTypeString);

        // Determine the size of the array (from `pos('[')+1` to typeString.length-2)
        string arraySizeString = typeString[lastOBracketPos+1..$-1];
        ulong arraySize = to!(ulong)(arraySizeString);
        DEBUG("StackArray (stack size): "~to!(string)(arraySize));


        DEBUG("typeString: "~typeString);

        stackArray = new StackArray(tc.getType(container, componentTypeString), arraySize);

        ERROR("Stack-based array types are still being implemented");
        // assert(false);
        return stackArray;
    }
    /* Pointer handling `<type>*` and Array handling `<type>*` */
    else if((lastIndexOf(typeString, "*") > -1) || (lastIndexOf(typeString, "[]") > -1))
    {
        // Find the `*` (if any)
        long starPos = lastIndexOf(typeString, "*");

        // Find the `[]` (if any)
        long brackPos = lastIndexOf(typeString, "[]");

        // Determine which one is the rightmost
        long rightmostTypePos;
        if(starPos > brackPos)
        {
            rightmostTypePos = starPos;
        }
        else
        {
            rightmostTypePos = brackPos;
        }

        long ptrTypePos = rightmostTypePos;
        string ptrType = typeString[0..(ptrTypePos)];
        DEBUG("TypeStr: "~typeString);
        ERROR("Pointer to '"~ptrType~"'");

        return new Pointer(tc.getType(container, ptrType));
    }
    
    
    
    /* TODO: Add all remaining types, BUGS probabloy occur on failed looks ups when hitting this */
    /* If unknown, return null */
    else
    {


        ERROR("getBuiltInType("~typeString~"): Failed to map to a built-in type");

        return null;
    }
}

/** 
 * Checks if the provided type string
 * contains at least one dot and that
 * it ends with a segment (in its path)
 * of which is a primtive type.

 * The ending segment (primtiive type)
 * is only returned, however, if the
 * preceding path was valid (in the
 * AST).
 *
 * Params:
 *   tc = the type checker
 *   container = the container
 *   typeString = the input type string
 * to test
 *   typeOut = the found primitive type
 * Returns: `true` if valid, `false`
 * otherwise
 */
private bool getLongFormPrimitiveType
(
    TypeChecker tc,
    Container container,
    string typeString,
    ref Type typeOut
)
{
    string[] segments = split(typeString, ".");

    /* Type names such as x.y.<builtInType>` */

    Type primitiveTypeFound;

    /** 
     * If there is at least one dot
     * and the last element is a
     * primtive type
     */
    if(segments.length >= 2 && getPrimitiveType(segments[$-1], primitiveTypeFound))
    {
        import tlang.compiler.typecheck.resolution : Resolver;
        Resolver resolver = tc.getResolver();

        // Construct path prior to the primitive type ending segment
        string priorTypeString = join(segments[0..$-1], ".");

        // Check that it is valid
        if(resolver.resolveBest(container, priorTypeString))
        {
            typeOut = primitiveTypeFound;
            return true;
        }
        // If prior type string does not reference
        // anything valid then the entire type is
        // invalid
        else
        {
            return false;
        }
    }
    /* Single type names like `int` are ignored */
    else
    {
        return false;
    }
}

/** 
 * Given a type string this returns true if the provided
 * type string is infact a stack array type
 *
 * Params:
 *   typeString = the type string to check
 * Returns: a true if it is s atck array, false
 *          otherwise.
 */
private bool isStackArray(string typeString)
{
    // FIXME: THis below will be picked up by `int[]` before us
    // e.g. int[][222] (a stack array of size 222 of `int[]` (a.k.a. `int*`))

    // TODO: Also how will we fix: int[222][] which is int[222]*, ak..a a pojnter to a stack array of size 222 which
    // ... is simply not a thing it would just be int[][] (int[]*) - irrespective of where the array is (on stack or heap)

    // TODO: Length check? Or parser would have caught?

    // Ensure `<...>[ <something> ]`
    if(typeString[$-1] == ']' && typeString[$-2] != '[')
    {
        return true;
    }

    return false;
}