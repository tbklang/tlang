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

/**
* TODO: We should write spec here like I want int and stuff of proper size so imma hard code em
* no machine is good if int is not 4, as in imagine short being max addressable unit
* like no, fuck that (and then short=int=long, no , that is shit AND is NOT WHAT TLANG aims for)
*/
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

    /* `int`, signed (2-complement) */
    if(cmp(typeString, "int") == 0)
    {
        return new Integer("int", 4, true);
    }
    /* `uint` unsigned */
    else if(cmp(typeString, "uint") == 0)
    {
        return new Integer("uint", 4, false);
    }
    /* `long`, signed (2-complement) */
    else if(cmp(typeString, "long") == 0)
    {
        return new Integer("long", 8, true);
    }
    /* `ulong` unsigned */
    else if(cmp(typeString, "ulong") == 0)
    {
        return new Integer("ulong", 8, false);
    }
    /* `short`, signed (2-complement) */
    else if(cmp(typeString, "short") == 0)
    {
        return new Integer("short", 2, true);
    }
    /* `ushort` unsigned */
    else if(cmp(typeString, "ushort") == 0)
    {
        return new Integer("ushort", 2, false);
    }
    /* `byte`, signed (2-complement) */
    else if(cmp(typeString, "byte") == 0)
    {
        return new Integer("byte", 1, true);
    }
    /* `ubyte` unsigned */
    else if(cmp(typeString, "ubyte") == 0)
    {
        return new Integer("ubyte", 1, false);
    }
    /* `void` */
    else if (cmp(typeString, "void") == 0)
    {
        return new Void();
    }
    /* TODO: Decide on these (floats and doubles need to be specced out) */
    /* `float` */
    else if(cmp(typeString, "float") == 0)
    {
        return new Float("float", 4);
    }
    /* `double` */
    else if(cmp(typeString, "double") == 0)
    {
        return new Float("double", 8);
    }
    
    
    /* TODO: What do we want? Char enforcement is kind of cringe I guess */
    else if(cmp(typeString, "char") == 0)
    {
        return new Integer("ubyte", 1, false);
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
        DEBUG("Pointer to '"~ptrType~"'");

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