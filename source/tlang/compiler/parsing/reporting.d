/**
 * Reporting types and utilities
 * for error reporting
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.compiler.parsing.reporting;

import tlang.compiler.lexer.core.tokens;
import std.string : strip, format;

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

    /** 
     * Returns the string represenation
     * of this line info
     *
     * Returns: a string
     */
    public string toString()
    {
        return format("LineInfo %s", getLine());
    }
}

public string report(Token offendingToken, string message)
{
    string line = offendingToken.getOrigin();

    // Needs to have an origin string
    if(!line.length)
    {
        // TODO: assret maybe?
        // return;
    }

    // FIXME: Double check the boundries here
    ulong pointerPos = offendingToken.getCoords().getColumn() < message.length ? offendingToken.getCoords().getColumn() : 0;
    assert(pointerPos < message.length);

    import std.stdio;
    import niknaks.debugging : genX;
    string pointer = format("%s^", genX(pointerPos, " "));
    
    /**
     * <message>
     *
     *    <originString>
     *        ^ (at pos)
     *
     * At <Coords>
     */
    string fullMessage = format("%s\n\n\t%s\n\t%s\n\nAt %s", message, line, pointer, offendingToken.getCoords());

    // import gogga;
    // gprintln(fullMessage, DebugType.ERROR);

    return fullMessage;
}

version(unittest)
{
    import gogga;
}

unittest
{
    string line = "int i = 20";
    import tlang.compiler.lexer.kinds.basic : BasicLexer;
    BasicLexer lex = new BasicLexer(line);
    lex.performLex();

    // TODO: In future when BasicLexer is updated
    // we should remove this
    lex.nextToken();
    Token offending = lex.getCurrentToken();
    offending.setOrigin(line);

    string s = report(offending, "Cannot name a variable i");
    gprintln(s);
}