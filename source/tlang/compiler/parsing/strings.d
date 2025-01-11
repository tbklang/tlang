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