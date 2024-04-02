/** 
 * Token and related types definitions
 */
module tlang.compiler.lexer.core.tokens;

import std.string : cmp, format;
import std.conv : to;
import tlang.compiler.reporting : Coords;

// TODO: Below could have linof?!?!?!

/** 
 * Defines a `Token` that a lexer
 * would be able to produce
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
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
     * The line this token was
     * lex'd from
     */
    private string origin;

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
     * Sets the origin string.
     * This is the line in which
     * this token was derived from.
     * 
     * Params:
     *   line = the line
     */
    public void setOrigin(string line)
    {
        this.origin = line;
    }

    /** 
     * Returns the origin string (if any)
     * from which this token was derived
     *
     * Returns: the line
     */
    public string getOrigin()
    {
        return this.origin;
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

    /** 
     * Returns the coordinates of
     * this token
     *
     * Returns: the `Coords`
     */
    public Coords getCoords()
    {
        return Coords(this.line, this.column);
    }

    // TODO: Switch to this
    import tlang.compiler.reporting :LineInfo;
    public LineInfo deriveLineInfo()
    {
        return LineInfo(getOrigin(), getCoords());
    }
}