/**
 * Helper routines for strings
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.parsing.strings;

import tlang.compiler.symbols.strings : StringExpression;

/** 
 * Creates a new `StringExpression` with the given
 * encoding details and the raw string contents
 * itself.
 *
 * Params:
 *   contents = the string without the enclosing `""`
 * characters
 *   encoding = the encoding to use
 * Returns: a new `StringExpression`
 */
public static StringExpression createExpression
(
    string contents,
    StrEnc encoding
)
{
    StringExpression str_exp;

    if(encoding == StrEnc.UTF_8)
    {
        // the `string` type is UTF-8
        str_exp = new StringExpression(contents);
    }
    else if(encoding == StrEnc.UTF_16)
    {
        import std.utf : toUTF16;
        str_exp = new StringExpression(toUTF16(contents));
    }
    else if(encoding == StrEnc.UTF_32)
    {
        import std.utf : toUTF32;
        str_exp = new StringExpression(toUTF32(contents));
    }
    else
    {
        assert(false);
    }

    return str_exp;
}

public enum StrEnc : ubyte
{
    UTF_8 = 1,
    UTF_16 = 2,
    UTF_32 = 4
}