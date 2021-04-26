module compiler.symbols.typing.core;

import compiler.symbols.data;
import std.string : cmp;

public import compiler.symbols.typing.builtins;

public bool isBuiltInType(string name)
{
    return cmp(name, "int") == 0 || cmp(name, "uint") == 0 ||
            cmp(name, "long") == 0 || cmp(name, "ulong") == 0;
}



public class Type : Entity
{
    /* TODO: Add width here */

    /**
    * TODO: See what we need in here, Entity name could be our Type name
    *       But to make it look nice we could just have `getType`
    *       Actually yeah, we should, as Number types won't be entities
    * Wait lmao they will
    */
    this(string name)
    {
        super(name);
    }
}

public final class Void : Type
{
    this()
    {
        super("void");
    }
}

/* TODO: Move width to Type class */
public class Number : Type
{
    /* Number of bytes (1,2,4,8) */
    private ubyte width;

    

    /* TODO: Aligbment details etc. */

    this(string name, ubyte width)
    {
        super(name);
        this.width = width;
    }
}

public class Integer : Number
{
    /* Whether or not signed (if so, then 2's complement) */
    private bool signed;

    this(string name, ubyte width, bool signed = false)
    {
        super(name, width);
        this.signed = signed;
    }
}

public class Float : Number
{
    this(string name)
    {
        /* TODO: Change */
        super(name, 69);
    }
}

public class Double : Number
{
    this(string name)
    {
        /* TODO: Change */
        super(name, 69);
    }
}

public class Pointer : Integer
{
    /* Data type being pointed to */
    private Type dataType;

    this(string name, Type dataType)
    {
        /* TODO: Change below, per architetcure */
        super(name, 8);
        this.dataType = dataType;
    }
}