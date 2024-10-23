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

    if(lv >= 0 && lv <= UBYTE_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "ubyte");
    }
    else if(lv >= 0 && lv <= USHORT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "ushort");
    }
    else if(lv >= 0 && lv <= UINT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "uint");
    }
    else if(lv >= 0 && lv <= ULONG_UPPER)
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

    if(lv >= 0 && lv <= BYTE_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "byte");
    }
    else if(lv >= 0 && lv <= SHORT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "short");
    }
    else if(lv >= 0 && lv <= INT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "int");
    }
    else if(lv >= 0 && lv <= LONG_UPPER)
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

    if(lv >= BYTE_LOWER && lv <= BYTE_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "byte");
    }
    else if(lv >= SHORT_LOWER && lv <= SHORT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "short");
    }
    else if(lv >= INT_LOWER && lv <= INT_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "int");
    }
    else if(lv >= LONG_LOWER && lv <= LONG_UPPER)
    {
        t = cast(Integer)getBuiltInType(null, null, "long");
    }

    assert(t);
    assert(t.isSigned());

    return t;
}

// Lower and uppers
public:
    enum UBYTE_UPPER = 255;
    enum USHORT_UPPER = 65_535;
    enum UINT_UPPER = 4_294_967_295;
    enum ULONG_UPPER = 18_446_744_073_709_551_615;

    enum BYTE_LOWER = -128;
    enum BYTE_UPPER = 127;
    enum SHORT_LOWER = -32_768;
    enum SHORT_UPPER = 32_767;
    enum INT_LOWER = -2_147_483_648;
    enum INT_UPPER = 2_147_483_647;
    enum LONG_LOWER = -9_223_372_036_854_775_808;
    enum LONG_UPPER = 9_223_372_036_854_775_807;
