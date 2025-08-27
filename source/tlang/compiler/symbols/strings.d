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
    public wstring utf16;
    public dstring utf32;
}

import tlang.compiler.parsing.strings : StrEnc;

/** 
 * Contains the raw string data
 * along with some information
 * regarding it
 */
public struct StringInfo
{
    private StringData _data;
    private StrEnc _width;

    invariant
    {
        assert(_width == StrEnc.UTF_8 || _width == StrEnc.UTF_16 || _width == StrEnc.UTF_32);
    }

    this(StringData data, StrEnc width)
    {
        this._data = data;
        this._width = width;
    }

    public StringData data()
    {
        return this._data;
    }

    public StrEnc width()
    {
        return this._width;
    }

    public string toString()
    {
        import std.string : format;
        if(_width == StrEnc.UTF_8)
        {
            return format("\"%s\" (UTF%d)", this._data.utf8, _width*8);
        }
        else if(_width == StrEnc.UTF_16)
        {
            return format("\"%s\" (UTF%d)", this._data.utf16, _width*8);
        }
        else if(_width == StrEnc.UTF_32)
        {
            return format("\"%s\" (UTF%d)", this._data.utf32, _width*8);
        }

        return null;
    }

    public auto utf8()
    {
        assert(_width == StrEnc.UTF_8);
        return this._data.utf8;
    }

    public auto utf16()
    {
        assert(_width == StrEnc.UTF_16);
        return this._data.utf16;
    }

    public auto utf32()
    {
        assert(_width == StrEnc.UTF_32);
        return this._data.utf32;
    }
}

/** 
 * A string expression
 */
public final class StringExpression : Expression
{
    private StringInfo _data;

    public this(StringData sd, StrEnc width)
    {
        this._data = StringInfo(sd, width);
    }

    public this(string zstring)
    {
        // UTF-8 multi-byte (smallest is 1 byte per-char)
        StringData sd;
        sd.utf8 = zstring;
        this(sd, StrEnc.UTF_8);
    }

    public this(wstring zstring)
    {
        // UTF-16 2-byte padded per-char ALWAYS
        StringData sd;
        sd.utf16 = zstring;
        this(sd, StrEnc.UTF_16);
    }

    public this(dstring zstring)
    {
        // UTF-32 4-byte padded per-char ALWAYS
        StringData sd;
        sd.utf32 = zstring;
        this(sd, StrEnc.UTF_32);
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


public StringInfo convertTo(StrEnc width, StringInfo src)
{
    import std.utf : toUTF8, toUTF16, toUTF32;
    StringData sd;

    if(width == src.width())
    {
        return src;
    }
    // UTF-8 to UTF-16
    else if(src.width() == StrEnc.UTF_8 && width == StrEnc.UTF_16)
    {
        sd.utf16 = toUTF16(src.data().utf8);
    }
    // UTF-8 to UTF-32
    else if(src.width() == StrEnc.UTF_8 && width == StrEnc.UTF_32)
    {
        sd.utf32 = toUTF32(src.data().utf8);
    }
    // UTF-16 to UTF-8
    else if(src.width() == StrEnc.UTF_16 && width == StrEnc.UTF_8)
    {
        sd.utf8 = toUTF8(src.data().utf16);
    }
    // UTF-16 to UTF-32
    else if(src.width() == StrEnc.UTF_16 && width == StrEnc.UTF_32)
    {
        sd.utf32 = toUTF32(src.data().utf16);
    }
    // UTF-32 to UTF-8
    else if(src.width() == StrEnc.UTF_32 && width == StrEnc.UTF_8)
    {
        sd.utf8 = toUTF8(src.data().utf32);
    }
    // UTF-32 to UTF-16
    else if(src.width() == StrEnc.UTF_32 && width == StrEnc.UTF_16)
    {
        sd.utf16 = toUTF16(src.data().utf32);
    }
    else
    {
        assert(false); // programming bug if we get here, then I missed something
    }

    return StringInfo(sd, width);
}

// rule: always go to the width of the bigger StringData of the two
public StringExpression combine(StringExpression left, StringExpression right)
{
    auto left_si = left.data(), right_si = right.data();
    StrEnc w_chosen = left_si.width();

    // left_si's width -> right_si's width
    if(left_si.width() < right_si.width())
    {
        w_chosen = right_si.width();
        left_si = convertTo(w_chosen, left_si);
    }
    // right_si's width -> left_si's width
    else if(left_si.width() > right_si.width())
    {
        w_chosen = left_si.width();
        right_si = convertTo(w_chosen, right_si);
    }

    // once converted (or if matched) we can then
    // combine
    StringData s_sid;
    if(w_chosen == StrEnc.UTF_8)
    {
        s_sid.utf8 = left_si.data().utf8~right_si.data().utf8;
    }
    else if(w_chosen == StrEnc.UTF_16)
    {
        s_sid.utf16 = left_si.data().utf16~right_si.data().utf16;
    }
    else if(w_chosen == StrEnc.UTF_32)
    {
        s_sid.utf32 = left_si.data().utf32~right_si.data().utf32;
    }

    StringExpression s_exp = new StringExpression(s_sid, w_chosen);
    return s_exp;
}

// TODO: Add a unittest here for conversions

unittest
{
    // create both with UTF-8 encoding
    StringExpression s1 = new StringExpression("Hello");
    StringExpression s2 = new StringExpression(" world");
    assert(s1.data().width == StrEnc.UTF_8 && s2.data().width == StrEnc.UTF_8);
    auto s_comb = combine(s1, s2);

    // ensure the combination is a UTF-8 encoded
    // string
    assert(s_comb.data().width == StrEnc.UTF_8);

    // ensure combination of data worked
    assert(s_comb.data().utf8() == "Hello world");
}

unittest
{
    // create both with UTF-16 encoding
    StringExpression s1 = new StringExpression("Hello"w);
    StringExpression s2 = new StringExpression(" world"w);
    assert(s1.data().width == StrEnc.UTF_16 && s2.data().width == StrEnc.UTF_16);
    auto s_comb = combine(s1, s2);

    // ensure the combination is a UTF-16 encoded
    // string
    assert(s_comb.data().width == StrEnc.UTF_16);

    // ensure combination of data worked
    assert(s_comb.data().utf16() == "Hello world"w);
}

unittest
{
    // create both with UTF-32 encoding
    StringExpression s1 = new StringExpression("Hello"d);
    StringExpression s2 = new StringExpression(" world"d);
    assert(s1.data().width == StrEnc.UTF_32 && s2.data().width == StrEnc.UTF_32);
    auto s_comb = combine(s1, s2);

    // ensure the combination is a UTF-32 encoded
    // string
    assert(s_comb.data().width == StrEnc.UTF_32);

    // ensure combination of data worked
    assert(s_comb.data().utf32() == "Hello world"d);
}

unittest
{
    // create one with UTF-8 encoding and another
    // with UTF-32 encoding
    StringExpression s1 = new StringExpression("Hello");
    StringExpression s2 = new StringExpression(" world"d);
    assert(s1.data().width == StrEnc.UTF_8 && s2.data().width == StrEnc.UTF_32);
    auto s_comb = combine(s1, s2);

    // then we should expect the bigger encoding scheme
    // of the two to be chosen; hence UTF-32
    assert(s_comb.data().width == StrEnc.UTF_32);

    // ensure combination of data worked
    import std.stdio;
    stderr.writeln(cast(ubyte[])s_comb.data().utf32());
    stderr.writeln(s_comb.data().utf32());
    assert(s_comb.data().utf32() == "Hello world"d);
}

unittest
{
    // create one with UTF-16 encoding and another
    // with UTF-8 encoding
    StringExpression s1 = new StringExpression("Hello"w);
    StringExpression s2 = new StringExpression(" world");
    assert(s1.data().width == StrEnc.UTF_16 && s2.data().width == StrEnc.UTF_8);
    auto s_comb = combine(s1, s2);

    // then we should expect the bigger encoding scheme
    // of the two to be chosen; hence UTF-16
    assert(s_comb.data().width == StrEnc.UTF_16);

    // ensure combination of data worked
    import std.stdio;
    stderr.writeln(cast(ubyte[])s_comb.data().utf16());
    stderr.writeln(s_comb.data().utf16());
    assert(s_comb.data().utf16() == "Hello world"w);
}