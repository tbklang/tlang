module tlang.compiler.typecheck.matching.types;

import tlang.compiler.symbols.typing.core : Type;

/** 
 * Describes a type signature
 * which is just a list of
 * types in a given order
 */
public struct TypeSignature
{
    private Type[] _tl;

    this(Type[] typeList)
    {
        this._tl = typeList;
    }
}