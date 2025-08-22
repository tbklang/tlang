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

    public this(StringData sd, ubyte width)
    {
        this._data = StringInfo(sd, width);
    }

    public this(string zstring)
    {
        // UTF-8 multi-byte (smallest is 1 byte per-char)
        StringData sd;
        sd.utf8 = zstring;
        this(sd, 1);
    }

    public this(wchar[] zstring)
    {
        // UTF-16 2-byte padded per-char ALWAYS
        StringData sd;
        sd.utf16 = zstring;
        this(sd, 2);
    }

    public this(dchar[] zstring)
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

    public override string toString()
    {
        return this._data.toString();
    }
}

// todo: we need to define a _single_ StringData hence the decision HAS TO
// be made here

// rule: always go to the width of the bigger StringData of the two
public StringExpression combine(StringExpression left, StringExpression right)
{
    auto left_si = left.data(), right_si = right.data();
    ubyte w_chosen = left_si.width();

    // left_si's width -> right_si's width
    if(left_si.width() < right_si.width())
    {
        w_chosen = right_si.width();
    }
    // right_si's width -> left_si's width
    else if(left_si.width() > right_si.width())
    {
        w_chosen = left_si.width();
    }

    
}