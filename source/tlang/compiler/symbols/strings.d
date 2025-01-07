/** 
 * String expression and related
 * types
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.strings;

import tlang.compiler.symbols.expressions : Expression;

/** 
 * The string data itself
 *
 * All of these are just
 * the same size as its
 * length + ptr
 */
public union StringData
{
    public string utf8;
    public wchar[] utf16;
    public dchar[] utf32;
}

/** 
 * Contains the raw string data
 * along with some information
 * regarding it
 */
public struct StringInfo
{
    private StringData _data;
    private ubyte _width;

    invariant
    {
        assert(_width == 1 || _width == 2 || _width == 4);
    }

    this(StringData data, ubyte width)
    {
        this._data = data;
        this._width = width;
    }

    public StringData data()
    {
        return this._data;
    }

    public ubyte width()
    {
        return this._width;
    }

    public string toString()
    {
        import std.string : format;
        if(_width == 1)
        {
            return format("\"%s\" (UTF%d)", this._data.utf8, _width*8);
        }
        else if(_width == 2)
        {
            return format("\"%s\" (UTF%d)", this._data.utf16, _width*8);
        }
        else if(_width == 4)
        {
            return format("\"%s\" (UTF%d)", this._data.utf32, _width*8);
        }

        return null;
    }

    public auto utf8()
    {
        assert(_width == 1);
        return this._data.utf8;
    }

    public auto utf16()
    {
        assert(_width == 2);
        return this._data.utf16;
    }

    public auto utf32()
    {
        assert(_width == 4);
        return this._data.utf32;
    }
}

/** 
 * A string expression
 */
public final class StringExpression : Expression
{
    private StringInfo _data;

    private this(StringData sd, ubyte width)
    {
        this._data = StringInfo(sd, width);
    }

    private this(string zstring)
    {
        // UTF-8 multi-byte (smallest is 1 byte per-char)
        StringData sd;
        sd.utf8 = zstring;
        this(sd, 1);
    }

    private this(wchar[] zstring)
    {
        // UTF-16 2-byte padded per-char ALWAYS
        StringData sd;
        sd.utf16 = zstring;
        this(sd, 2);
    }

    private this(dchar[] zstring)
    {
        // UTF-32 4-byte padded per-char ALWAYS
        StringData sd;
        sd.utf32 = zstring;
        this(sd, 4);
    }

    public StringInfo data()
    {
        return this._data;
    }

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
     * Returns: 
     */
    public static StringExpression buildUTF8FromLiteral(string stringLiteral)
    {
        assert(stringLiteral.length >= 2);
        assert(stringLiteral[0] == stringLiteral[$-1]);

        // if `""` then it's empty string ``, else it is `<stuff between "">`
        string str_trimmed = stringLiteral.length > 2 ? stringLiteral[1..$-1] : "";

        return new StringExpression(str_trimmed);
    }

    public override string toString()
    {
        return this._data.toString();
    }
}