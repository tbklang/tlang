module tlang.compiler.symbols.typing.core;

import tlang.compiler.symbols.data;
import std.string : cmp;
import std.conv : to;

public import tlang.compiler.symbols.typing.builtins;

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

    // TODO: A comparator would be nice but I would have to then see
    // ... where referene equality was used, hence I stear clear of that
}

public final class Void : Primitive
{
    this()
    {
        super("void");
    }
}

public class Primitive : Type
{
    this(string name)
    {
        super(name);
    }
}

/* TODO: Move width to Type class */
public class Number : Primitive
{
    /* Number of bytes (1,2,4,8) */
    private ubyte width;

    

    /* TODO: Aligbment details etc. */

    this(string name, ubyte width)
    {
        super(name);
        this.width = width;
    }

    public final ubyte getSize()
    {
        return width;
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

    public final bool isSigned()
    {
        return signed;
    }

    /* TODO: Remove ig */
    public override string toString()
    {
        return name;
    }
}

public class Float : Number
{
    this(string name, ubyte width)
    {
        super(name, width);
    }
}

public class Pointer : Integer
{
    /* Data type being pointed to */
    private Type dataType;

    this(Type dataType)
    {
        /* The name should be `dataType*` */
        string name = dataType.toString()~"*";
        
        /* TODO: Change below, per architetcure (the 8 byte width) */
        super(name, 8);
        this.dataType = dataType;
    }

    public Type getReferredType()
    {
        return dataType;
    }
}

/**
* Stack-based Array type
*/
public class StackArray : Type
{
    /* Size of the stack array to allocate */
    private ulong arraySize;

    /* Component type */
    private Type elementType;

    this(Type elementType, ulong arraySize)
    {
        /* The name should be `elementType[arraySize]` */
        super(to!(string)(elementType)~"["~to!(string)(arraySize)~"]");

        this.elementType = elementType;
        this.arraySize = arraySize;
    }

    public Type getComponentType()
    {
        return elementType;
    }

    public ulong getAllocatedSize()
    {
        return arraySize;
    }
}