module compiler.symbols.typing.builtins;

import compiler.symbols.typing.core;
import std.string : cmp, indexOf, lastIndexOf;
import gogga;
import compiler.typecheck.core;

/**
* TODO: We should write spec here like I want int and stuff of proper size so imma hard code em
* no machine is good if int is not 4, as in imagine short being max addressable unit
* like no, fuck that (and then short=int=long, no , that is shit AND is NOT WHAT TLANG aims for)
*/
public Type getBuiltInType(TypeChecker tc, string typeString)
{
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
    
    /* TODO: char */
    else if(cmp(typeString, "char") == 0)
    {
        return new Integer("ubyte", 1, false);
    }

    /* Pointer handling `<type>*` */
    else if(lastIndexOf(typeString, "*") > -1)
    {
        /* FIXME: We may need to recurse call, for Pointer generation */
        long ptrTypePos = lastIndexOf(typeString, "*");
        string ptrType = typeString[0..(ptrTypePos)];
        gprintln("Pointer to '"~ptrType~"'");

        return new Pointer(tc.getType(tc.getModule(), ptrType));
    }
    
    
    /* TODO: Add all remaining types, BUGS probabloy occur on failed looks ups when hitting this */
    /* If unknown, return null */
    else
    {
        
        /* If it contains a `[]` then its an array type */
        if(indexOf(typeString, "[]") > -1)
        {
            /* FIXME: Implement me */
        }
        




        return null;
    }
}