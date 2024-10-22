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

import tlang.compiler.symbols.typing.core : Integer, Type, getBuiltInType;

// NOTE (X-platform): For cross-platform sake we should change the `ulong` to `size_t`

/** 
 * Determines the type based on
 * the provided unsigned integer
 *
 * Params:
 *   lv = the unsigned integral
 * value
 * Returns: the `Integer`
 */
public Integer typeFromUnsignedRange(ulong lv)
{
    Integer t;

    if(lv >= 0 && lv <= 255)
    {
        t = cast(Integer)getBuiltInType(null, null, "ubyte");
    }
    else if(lv >= 0 && lv <= 65_535)
    {
        t = cast(Integer)getBuiltInType(null, null, "ushort");
    }
    else if(lv >= 0 && lv <= 4_294_967_295)
    {
        t = cast(Integer)getBuiltInType(null, null, "uint");
    }
    else if(lv >= 0 && lv <= 18_446_744_073_709_551_615)
    {
        t = cast(Integer)getBuiltInType(null, null, "ulong");
    }

    assert(t);
    assert(!t.isSigned());
    return t;
}

/** 
 * Determines the type based on
 * the provided signed integer's
 * positive range
 *
 * Params:
 *   lv = the signed integral
 * value
 * Returns: the `Integer`
 */
public Integer typeFromSignedRangePositive(ulong lv)
{
    Integer t;

    if(lv >= 0 && lv <= 127)
    {
        t = cast(Integer)getBuiltInType(null, null, "byte");
    }
    else if(lv >= 0 && lv <= 32_767)
    {
        t = cast(Integer)getBuiltInType(null, null, "short");
    }
    else if(lv >= 0 && lv <= 2_147_483_647)
    {
        t = cast(Integer)getBuiltInType(null, null, "int");
    }
    else if(lv >= 0 && lv <= 9_223_372_036_854_775_807)
    {
        t = cast(Integer)getBuiltInType(null, null, "long");
    }

    assert(t);
    assert(t.isSigned());

    return t;
}

/** 
 * Determines the type based on
 * the provided signed integer's
 * positive range AND negative
 * range
 *
 * Params:
 *   lv = the signed integral
 * value
 * Returns: the `Integer`
 */
public Integer typeFromSignedRangeNegative(long lv)
{
    Integer t;

    if(lv >= -128 && lv <= 127)
    {
        t = cast(Integer)getBuiltInType(null, null, "byte");
    }
    else if(lv >= -32_768 && lv <= 32_767)
    {
        t = cast(Integer)getBuiltInType(null, null, "short");
    }
    else if(lv >= -2_147_483_648 && lv <= 2_147_483_647)
    {
        t = cast(Integer)getBuiltInType(null, null, "int");
    }
    else if(lv >= -9_223_372_036_854_775_808 && lv <= 9_223_372_036_854_775_807)
    {
        t = cast(Integer)getBuiltInType(null, null, "long");
    }

    assert(t);
    assert(t.isSigned());

    return t;
}