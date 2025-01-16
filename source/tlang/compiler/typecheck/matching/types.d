module tlang.compiler.typecheck.matching.types;

import tlang.compiler.symbols.typing.core : Type;
import tlang.compiler.typecheck.core : TypeChecker;

import niknaks.functional : Result, ok, error;
import tlang.misc.logging;

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

    // TODO: Return a Result!(void, string) where
    // in the case of an error we put the error text
    // in there?
    private alias NONE_TYPE = string;
    public Result!(NONE_TYPE, string) cmp(TypeSignature rhs)
    {
        import std.string : format;
        if(this._tl.length != rhs.typeList().length)
        {
            return error!(string, NONE_TYPE)
            (
                format
                (
                    "Mismatch between type lists for signatures '%s' (%d types) and '%s' (%d types)",
                    name(),
                    typeList().length,
                    rhs.name(),
                    rhs.typeList().length
                )
            );
        }

        for(size_t i = 0; i < this._tl.length; i++)
        {
            Type this_t = this._tl[i];
            Type rhs_t = rhs.typeList()[i];
            if(!_tc.isSameType(this_t, rhs_t))
            {
                return error!(string, NONE_TYPE)
                (
                    format
                    (
                        "Type signature '%s' has type %s at %d but type signature '%s' has type %s at %d",
                        name(),
                        this_t,
                        i,
                        rhs.name(),
                        rhs_t,
                        i
                    )
                );
            }
        }

        if(this._name != rhs.name())
        {
            return error!(string, NONE_TYPE)
            (
                format
                (
                    "Mismatched type signature names, '%s' != '%s'",
                    name(),
                    rhs.name()
                )
            );
        }

        return ok!(NONE_TYPE, string)(NONE_TYPE.init);
    }

    public bool opEquals(TypeSignature rhs)
    {
        auto res = cmp(rhs);
        DEBUG(res);
        return res.is_okay();
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


/**
 * Types match and name matches
 */
unittest
{
    string sourceFile = "source/tlang/testing/empty.t";

    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", t2_tl);

    assert(t1 == t2);
}

/**
 * Types don't match
 */
unittest
{
    string sourceFile = "source/tlang/testing/empty.t";
    
    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "byte")];
    TypeSignature t2 = TypeSignature(tc, "+", t2_tl);

    assert(t1 != t2);
}

/**
 * Types don't match
 */
unittest
{
    string sourceFile = "source/tlang/testing/empty.t";
    
    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", t2_tl);

    assert(t1 != t2);
}

/**
 * Types match but names don't match
 */
unittest
{
    string sourceFile = "source/tlang/testing/empty.t";
    
    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "-", t2_tl);

    assert(t1 != t2);
}