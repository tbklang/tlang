/**
 * Reporting types and utilities
 * for error reporting
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.reporting;

import tlang.compiler.lexer.core.tokens;
import std.string : strip, format;

/** 
 * Represents coordinates
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
public struct Coords
{
    private ulong line;
    private ulong column;

    /** 
     * Constructs a new set of coordinates
     *
     * Params:
     *   line = the line
     *   column = the column
     */
    this(ulong line, ulong column)
    {
        this.line = line;
        this.column = column;
    }

    /** 
     * Returns the line
     *
     * Returns: line index
     */
    public ulong getLine()
    {
        return this.line;
    }

    /** 
     * Returns the column
     *
     * Returns: column index
     */
    public ulong getColumn()
    {
        return this.column;
    }

    /** 
     * Returns a string representation
     *
     * Returns: the coordinates
     */
    public string toString()
    {
        return format("line %d, column %d", this.line, this.column);
    }
}

/** 
 * Represents line information
 * which couples the line itself
 * with the coordinates as well
 * 
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
public struct LineInfo
{
    private string line;
    private Coords location;
    
    /** 
     * Constructs a new `LineInfo`
     * combining the line and its
     * location
     *
     * Params:
     *   line = the line itself
     *   location = the location
     */
    this(string line, Coords location)
    {
        this.line = line;
        this.location = location;
    }

    /** 
     * Returns the line itself
     *
     * Returns: the line
     */
    public string getLine()
    {
        return this.line;
    }

    /** 
     * Returns the location
     * of this line
     *
     * Returns: the `Coords`
     */
    public Coords getLocation()
    {
        return this.location;
    }

    /** 
     * Returns the string represenation
     * of this line info
     *
     * Returns: a string
     */
    public string toString()
    {
        return format("%s at %s", getLine(), getLocation());
    }
}

public string report(string message, LineInfo linfo, ulong cursor = 0)
{
    // Obtain the offending line
    string offendingLine = linfo.getLine();

    // Obtain where the offending line occurs
    Coords offendingLocation = linfo.getLocation();

    import std.stdio;
    import niknaks.debugging : genX;
    string pointer = format("%s^", genX(cursor, " "));
    
    /**
     * <message>
     *
     *    <originString>
     *        ^ (at pos)
     *
     * At <Coords>
     */
    string fullMessage = format
                        (
                            "%s\n\n\t%s\n\t%s\n\nAt %s",
                            message,
                            offendingLine,
                            pointer,
                            offendingLocation
                        );

    return fullMessage;
}

public string report(Token offendingToken, string message)
{
    string line = offendingToken.getOrigin();

    // FIXME: Double check the boundries here
    ulong pointerPos = offendingToken.getCoords().getColumn() < message.length ? offendingToken.getCoords().getColumn() : 0;
    assert(pointerPos < message.length);

    return report(message, offendingToken.deriveLineInfo(), pointerPos);
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