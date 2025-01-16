module tlang.compiler.typecheck.matching.types;

import tlang.compiler.symbols.typing.core : Type;

/** 
 * Describes a type signature
 * which is a name coupled with
 * an ordered list of types
 */
public struct TypeSignature
{
    private string _name;
    private Type[] _tl;

    this(string name, Type[] typeList)
    {
        this._name = name;
        this._tl = typeList;
    }

    public string name()
    {
        return this._name;
    }

    // TODO: make this unmodifiable (the returned list)
    public Type[] typeList()
    {
        return this._tl;
    }

    public bool opEquals(TypeSignature rhs)
    {
        return this._name == rhs.name() && this._tl == rhs.typeList();
    }
}

version(unittest)
{
    import tlang.compiler.symbols.typing.core : Type;
    import tlang.compiler.symbols.typing.builtins : getBuiltInType;
    // import tlang.compiler.typecheck.core : TypeChecker;
}
unittest
{
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature("+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature("+", t2_tl);

    assert(t1 == t2);
}