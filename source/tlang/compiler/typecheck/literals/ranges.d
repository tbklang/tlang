/**
 * Aids with working with integer ranges
 * and determining which type they belonmg
 * to
 *
 * All these functions are very simple and
 * require no type checker instance at all.
 *
 * Date: 22nd of October 2024
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.compiler.typecheck.literals.ranges;

import tlang.compiler.symbols.typing.core : Type, getBuiltInType;


// NOTE (X-platform): For cross-platform sake we should change the `ulong` to `size_t`

/** 
 * Determines the type based on
 * the provided unsigned integer
 *
 * Params:
 *   range = the unsigned integral
 * value
 * Returns: the `Type`
 */
public Type typeFromUnsignedRange(ulong lv)
{
    Type t;

    if(lv >= 0 && lv <= 255)
    {
        t = getBuiltInType(null, null, "ubyte");
    }
    else if(lv >= 0 && lv <= 65_535)
    {
        t = getBuiltInType(null, null, "ushort");
    }
    else if(lv >= 0 && lv <= 4_294_967_295)
    {
        t = getBuiltInType(null, null, "uint");
    }
    else if(lv >= 0 && lv <= 18_446_744_073_709_551_615)
    {
        t = getBuiltInType(null, null, "ulong");
    }

    assert(t);
    return t;
}