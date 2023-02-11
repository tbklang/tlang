module tlang.compiler.symbols.typing.builtins;

import tlang.compiler.symbols.typing.core;
import std.string : cmp, indexOf, lastIndexOf;
import gogga;
import tlang.compiler.typecheck.core;
import std.conv : to;

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


    /**
    * FIXME: For the below we need to find which is the RIGHT-MOST and THEN
    * go from there
    *
    * This is so that we can support things such as:
    *
    * `char*[]`

    * Current problem here is that if we have `int*[]`
    * it will immediately start with `int*` -> new Pointer(int)
    *
    * Instead of `new Pointer(int*)`
    *
    * Switching the pointer-array checks arround doesn't help
    * as the above works but then `int[]*` will be new Pointer(int)
    * (and leaving out the `*`)
    */

    

    /* Pointer handling `<type>*` */
    else if(lastIndexOf(typeString, "*") > -1)
    {
        gprintln("PtrLstIndexOf: "~to!(string)(lastIndexOf(typeString, "*")));
        gprintln("ArrayLstIndexOf: "~to!(string)(lastIndexOf(typeString, "[]")));

        long ptrTypePos = lastIndexOf(typeString, "*");
        string ptrType = typeString[0..(ptrTypePos)];
        gprintln("TypeStr: "~typeString);
        gprintln("Pointer to '"~ptrType~"'", DebugType.ERROR);

        return new Pointer(tc.getType(tc.getModule(), ptrType));
    }
    /* Array handling `<type>[]` */
    else if(lastIndexOf(typeString, "[]") > -1)
    {
        gprintln("PtrLstIndexOf: "~to!(string)(lastIndexOf(typeString, "*")));
        gprintln("ArrayLstIndexOf: "~to!(string)(lastIndexOf(typeString, "[]")));

        long arrayTypePos = lastIndexOf(typeString, "[]");
        string arrayType = typeString[0..(arrayTypePos)];
        gprintln("Array of '"~arrayType~"'", DebugType.WARNING);

        // NOTE: We disabled the below as we are basically just a pointer type
        // return new Array(tc.getType(tc.getModule(), arrayType));
        return new Pointer(tc.getType(tc.getModule(), arrayType));
    }
    // TODO: Add support for arrays like `[<number>]`
    
    
    /* TODO: Add all remaining types, BUGS probabloy occur on failed looks ups when hitting this */
    /* If unknown, return null */
    else
    {




        return null;
    }
}