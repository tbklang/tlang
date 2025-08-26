/**
 * Helper routines for strings
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.parsing.strings;

import tlang.compiler.symbols.strings : StringExpression;

/** 
 * Builds a new `StringExpression` from the
 * given raw token input. This input should
 * start and end with the same character, hence
 * the minimum length is that of 2 characters.
 *
 * These beginning and ending characters will
 * be stripped and the string's raw contents
 * will be stored
 *
 * Params:
 *   stringLiteral = the string literal
 * Returns: a new `StringExpression`
 */
public static StringExpression buildUTF8FromLiteral(string stringLiteral)
{
    assert(stringLiteral.length >= 2);
    assert(stringLiteral[0] == stringLiteral[$-1]);

    // if `""` then it's empty string ``, else it is `<stuff between "">`
    string str_trimmed = stringLiteral.length > 2 ? stringLiteral[1..$-1] : "";

    return new StringExpression(str_trimmed);
}

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