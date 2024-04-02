/**
 * Reporting types and utilities
 * for error reporting
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.compiler.parsing.reporting;

import tlang.compiler.lexer.core.tokens;
import std.string : strip;

/** 
 * Represents line information
 */
public struct LineInfo
{
    private Token[] line;

    /** 
     * Appends the given token to the
     * line
     *
     * Params:
     *   tok = the token to append
     */
    public void add(Token tok)
    {
        this.line ~= tok;
    }

    /** 
     * Clears all tokens from
     * this line info
     */
    public void clear()
    {
        this.line.length = 0;
    }

    /** 
     * Returns the coordinates of
     * the start of the line
     *
     * Returns: starting coordinates
     */
    public Coords getStart()
    {
        return this.line.length ? this.line[0].getCoords() : Coords(0,0);
    }

    /** 
     * Returns the coordinates of
     * the end of the line
     *
     * Returns: ending coordinates
     */
    public Coords getEnd()
    {
        return this.line.length ? this.line[$-1].getCoords() : Coords(0,0);
    }

    /** 
     * Returns the complete line
     * of all tokens strung together
     *
     * Returns: the line
     */
    public string getLine()
    {
        string fullLine;
        foreach(Token tok; this.line)
        {
            fullLine ~= tok.getToken() ~" ";
        }

        fullLine = strip(fullLine);
        return fullLine;
    }
}