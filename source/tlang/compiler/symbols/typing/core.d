/**
 * Data structures which represent kind-of `Entity`(s),
 * starting with the base-`Entity`, `Type`, which represents
 * a name that describes a data type
 */
module tlang.compiler.symbols.typing.core;

import tlang.compiler.symbols.data;
import std.string : cmp;
import std.conv : to;

public import tlang.compiler.symbols.typing.builtins;

/**
 * The base entity from which all types are derived
 * from
 */
public class Type : Entity
{
    /* TODO: Add width here */

    /**
    * TODO: See what we need in here, Entity name could be our Type name
    *       But to make it look nice we could just have `getType`
    *       Actually yeah, we should, as Number types won't be entities
    * Wait lmao they will
    */

    /** 
     * Constructs a new `Type` with the
     * given name
     *
     * Params:
     *   name = the new type's name
     */
    this(string name)
    {
        super(name);
    }

    // TODO: A comparator would be nice but I would have to then see
    // ... where referene equality was used, hence I stear clear of that
}

/** 
 * Represents a void type, a type
 * which has no return value for it
 */
public final class Void : Primitive
{
    /** 
     * Constructs a new `Void` type
     */
    this()
    {
        super("void");
    }
}

/** 
 * Represents all primitive data types
 */
public class Primitive : Type
{
    /** 
     * Constructs a new `Primitive`
     * type
     *
     * Params:
     *   name = the new type's name
     */
    this(string name)
    {
        super(name);
    }
}

/* TODO: Move width to Type class */
/** 
 * Represents any kind of number
 *
 * This means it has a width associated
 * with it which is the number of bytes
 * wide it is
 */
public class Number : Primitive
{
    /** 
     * Number of bytes (1,2,4,8)
     */
    private ubyte width;

    /* TODO: Aligbment details etc. */
    /** 
     * COnstructs a new `Number` type
     * with the given name and width
     *
     * Params:
     *   name = the new type's name
     *   width = the bit-width (in bytes)
     */
    this(string name, ubyte width)
    {
        super(name);
        this.width = width;
    }

    /** 
     * Returns the bit-width of this number
     *
     * Returns: the width in bytes
     */
    public final ubyte getSize()
    {
        return width;
    }
}

/** 
 * Represents an integer, a kind-of `Number`,
 * but with a signedness/unsignedness encoding
 * scheme associated with it
 */
public class Integer : Number
{
    /** 
     * Whether or not signed (if so, then 2's complement)
     */
    private bool signed;

    /** 
     * Constructs a new `Integer` type with the given
     * parameters
     *
     * Params:
     *   name = the name of this type
     *   width = the bit-width (in bytes)
     *   signed = whether or not it represents a
     * two's complement signed integer or not
     */
    this(string name, ubyte width, bool signed = false)
    {
        super(name, width);
        this.signed = signed;
    }

    /** 
     * Determines if the type of
     * integer being described is signed
     * or not
     *
     * Returns: `true` if signed, `false`
     * otherwise
     */
    public final bool isSigned()
    {
        return signed;
    }

    /* TODO: Remove ig */
    /** 
     * Returns a string representation of
     * this `Integer` type
     *
     * Returns: a `string`
     */
    public override string toString()
    {
        return name;
    }
}

/** 
 * Represents a floating point number
 */
public class Float : Number
{
    /** 
     * Constructs a new floating point
     * type with the given name and width
     *
     * Params:
     *   name = this type's name
     *   width = the width (in bytes) of
     * the floating point
     */
    this(string name, ubyte width)
    {
        super(name, width);
    }
}

/** 
 * A `Pointer`, is a kind-of `Integer`
 * which is unsigned. This represents
 * a memory address and is CURRENTLY
 * set to `8` bytes (TODO: Change this
 * to be dependent on the system used
 * basically it should actually take
 * in a size)
 *
 * A pointer is a 64-bit integer
 * that point to data in memory of
 * another given type
 */
public class Pointer : Integer
{
    /** 
     * Data type being pointed to
     */
    private Type dataType;

    /** 
     * Constructs a new `Pointer` to point
     * to data of the given type
     *
     * Params:
     *   dataType = the `Type` of data being
     * pointed to
     */
    this(Type dataType)
    {
        /* The name should be `dataType*` */
        string name = dataType.toString()~"*";
        
        /* TODO: Change below, per architetcure (the 8 byte width) */
        super(name, 8);
        this.dataType = dataType;
    }

    /** 
     * Returns the `Type` of the data this
     * pointer refers to
     *
     * Returns: the `Type`
     */
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
    /** 
     * Size of the stack array to allocate
     */
    private ulong arraySize;

    /** 
     * Component type
     */
    private Type elementType;

    /** 
     * Constructs a new `StackArray` type
     * with the given type of element and
     * the size to allocate on the stack
     *
     * Params:
     *   elementType = the component `Type`
     *   arraySize = the stack allocation size
     */
    this(Type elementType, ulong arraySize)
    {
        /* The name should be `elementType[arraySize]` */
        super(to!(string)(elementType)~"["~to!(string)(arraySize)~"]");

        this.elementType = elementType;
        this.arraySize = arraySize;
    }

    /** 
     * Gets the stack array's element type
     *
     * Returns: the `Type` of the components
     */
    public Type getComponentType()
    {
        return elementType;
    }

    /** 
     * Gets the size to be allocated on the stack
     * for this array
     *
     * Returns: the size
     */
    public ulong getAllocatedSize()
    {
        return arraySize;
    }
}

public final class ModuleType : Type
{
    this()
    {
        super("module");
    }
}

public final class ContainerType : Type
{
    this()
    {
        super("container");
    }

    public override string toString()
    {
        return "containerType";
    }
}