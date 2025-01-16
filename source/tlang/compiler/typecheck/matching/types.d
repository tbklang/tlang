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
}