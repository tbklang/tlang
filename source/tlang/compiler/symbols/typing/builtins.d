module compiler.symbols.typing.builtins;

import compiler.symbols.typing.core;
import std.string : cmp;

/**
* TODO: We should write spec here like I want int and stuff of proper size so imma hard code em
* no machine is good if int is not 4, as in imagine short being max addressable unit
* like no, fuck that (and then short=int=long, no , that is shit AND is NOT WHAT TLANG aims for)
*/
public Type getBuiltInType(string typeString)
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
    /* TODO: Add all remaining types */
    /* If unknown, return null */
    else
    {
        return null;
    }
}