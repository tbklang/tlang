/** 
 * Token definition
 */
module tlang.compiler.lexer.core.tokens;

import std.string : cmp;
import std.conv : to;

/** 
 * Defines a `Token` that a lexer
 * would be able to produce
 */
public final class Token
{
    /** 
     * The token
     */
    private string token;

    /** 
     * Line number information
     */
    private ulong line, column;

    /** 
     * Constructs a new `Token` with the given
     * contents and line information
     *
     * Params:
     *   token = the actual string
     *   line = the line it occurs at
     *   column = the column it occurs at
     */
    this(string token, ulong line, ulong column)
    {
        this.token = token;
        this.line = line;
        this.column = column;
    }

    /** 
     * Overrides the `==` operator to do equality
     * based on the stored token's contents
     *
     * Params:
     *   other = the other `Token` being compared to
     * Returns: true if the contents of the two tokens
     * match, false otherwise
     */
    override bool opEquals(Object other)
    {
        return cmp(token, (cast(Token)other).getToken()) == 0;
    }

    /** 
     * Rerturns a string representation of the token including
     * its data and line information
     *
     * Returns: a `string`
     */
    override string toString()
    {
        /* TODO (Column number): Don't adjust here, do it maybe in the lexer itself */
        return token~" at ("~to!(string)(line)~", "~to!(string)(column-token.length)~")";
    }

    /** 
     * Returns the token's contents
     *
     * Returns: a `string`
     */
    public string getToken()
    {
        return token;
    }
}