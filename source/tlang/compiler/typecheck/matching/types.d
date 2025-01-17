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

    private Type _rt;

    package this(TypeChecker tc, string name, Type returnType, Type[] typeList)
    {
        this._tc = tc;
        this._name = name;
        this._rt = returnType;
        this._tl = typeList;
    }

    public string name()
    {
        return this._name;
    }

    public Type returnType()
    {
        return this._rt;
    }

    // TODO: make this unmodifiable (the returned list)
    public Type[] typeList()
    {
        return this._tl;
    }

    // TODO: Return a Result!(void, string) where
    // in the case of an error we put the error text
    // in there?

    public Result!(bool, string) cmp(TypeSignature rhs)
    {
        import std.string : format;

        if(this._name != rhs.name())
        {
            return error!(string, bool)
            (
                format
                (
                    "Mismatched type signature names, '%s' != '%s'",
                    name(),
                    rhs.name()
                )
            );
        }

        Type this_rt = returnType();
        Type rhs_rt = rhs.returnType();
        if(!_tc.isSameType(this_rt, rhs_rt))
        {
            return error!(string, bool)
            (
                format
                (
                    "Mismatch between type %s (returned by '%s') and %s (returned by '%s')",
                    this_rt,
                    name(),
                    rhs_rt,
                    rhs.name()
                )
            );
        }

        if(this._tl.length != rhs.typeList().length)
        {
            return error!(string, bool)
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
                return error!(string, bool)
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

        

        return ok!(bool, string)(true);
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
    TypeSignature t1 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t2_tl);

    assert(t1 == t2);
}

/**
 * Types match and name matches
 * but return/evaluation type
 * doesn't
 */
unittest
{
    string sourceFile = "source/tlang/testing/empty.t";

    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    Type[] t1_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t1 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", getBuiltInType(null, null, "byte"), t2_tl);

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
    TypeSignature t1 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "byte")];
    TypeSignature t2 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t2_tl);

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
    TypeSignature t1 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t2_tl);

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
    TypeSignature t1 = TypeSignature(tc, "+", getBuiltInType(null, null, "ubyte"), t1_tl);

    Type[] t2_tl = [getBuiltInType(null, null, "ubyte"), getBuiltInType(null, null, "ubyte")];
    TypeSignature t2 = TypeSignature(tc, "-", getBuiltInType(null, null, "ubyte"), t2_tl);

    assert(t1 != t2);
}