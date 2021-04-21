module compiler.symbols.typing;

import compiler.symbols.data;

public class Type : Entity
{
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

public class Number : Type
{
    /* Number of bytes (1,2,4,8) */
    private ubyte width;

    this(string name)
    {
        super(name);
    }
}

public class Integer : Number
{
    this(string name)
    {
        super(name);
    }
}

public class Float : Number
{
    this(string name)
    {
        super(name);
    }
}

public class Double : Number
{
    this(string name)
    {
        super(name);
    }
}

public class Pointer : Type
{
    /* Datum wdith */
    private ubyte datumWidth;

    this(string name)
    {
        super(name);
    }
}