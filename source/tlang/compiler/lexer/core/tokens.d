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
    /* The token */
    private string token;

    /* Line number information */
    private ulong line, column;

    this(string token, ulong line, ulong column)
    {
        this.token = token;
        this.line = line;
        this.column = column;
    }

    override bool opEquals(Object other)
    {
        return cmp(token, (cast(Token)other).getToken()) == 0;
    }

    override string toString()
    {
        /* TODO (Column number): Don't adjust here, do it maybe in the lexer itself */
        return token~" at ("~to!(string)(line)~", "~to!(string)(column-token.length)~")";
    }

    public string getToken()
    {
        return token;
    }
}