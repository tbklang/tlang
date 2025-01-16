module tlang.compiler.typecheck.matching.types;

import tlang.compiler.symbols.typing.core : Type;
import tlang.compiler.typecheck.core : TypeChecker;

/** 
 * Describes a type signature
 * which is a name coupled with
 * an ordered list of types
 */
public struct TypeSignature
{
    private TypeChecker _tc; // for type comparisons

    private string _name;
    private Type[] _tl;

    package this(TypeChecker tc, string name, Type[] typeList)
    {
        this._tc = tc;
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
        if(this._tl.length != rhs.typeList().length)
        {
            return false;
        }

        for(size_t i = 0; i < this._tl.length; i++)
        {
            Type this_t = this._tl[i];
            Type rhs_t = rhs.typeList()[i];
            if(!_tc.isSameType(this_t, rhs_t))
            {
                return false;
            }
        }

        return this._name == rhs.name();
    }
}

version(unittest)
{
    import tlang.compiler.symbols.typing.core : Type;
    import tlang.compiler.symbols.typing.builtins : getBuiltInType;
    import tlang.compiler.typecheck.core : TypeChecker;
    import tlang.compiler.core;
    import std.stdio : File;
}


unittest
{
    string sourceFile = "source/tlang/testing/empty.t";
    File outFile;
    outFile.open("tlangout.c", "w");

    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, outFile);
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", t2_tl);

    assert(t1 == t2);
}