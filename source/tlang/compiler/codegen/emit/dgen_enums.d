module tlang.compiler.codegen.emit.dgen_enums;

import std.string : format;
import tlang.compiler.symbols.typing.enums : Enum;

// TODO: Move to seperate module
private struct EnumNameStore
{
    // Original name -> mapped name
    private string[string] sl;

    public string mapName(string n_i, size_t n_num)
    {
        string* n_o = n_i in this.sl;
        if(n_o is null)
        {
            this.sl[n_i] = format("%s_%d", n_i, n_num);
            return mapName(n_i, n_num);
        }
        return *n_o;
    }
}

// TODO: Move to seperate module
public class EnumMapper
{
    private size_t _roll;
    private EnumNameStore[Enum] _s;

    this()
    {
        
    }

    private EnumNameStore* enter(Enum e)
    {
        EnumNameStore* _es = e in _s;
        if(_es is null)
        {
            this._s[e] = EnumNameStore();
            return enter(e);
        }
        return _es;
    }

    public string getName(Enum e, string m)
    {
        scope(exit)
        {
            this._roll++;
        }

        EnumNameStore* _es = enter(e);
        return _es.mapName(m, this._roll);
    }
}