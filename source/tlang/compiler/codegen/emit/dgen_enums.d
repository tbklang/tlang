module tlang.compiler.codegen.emit.dgen_enums;

import std.string : format;
import tlang.compiler.symbols.typing.enums : Enum;

/** 
 * Enum member lookup table
 */
private struct EnumNameStore
{
    // Original name -> mapped name
    private string[string] sl;

    /** 
     * Looks up the mapped name for the
     * given member at the provided name.
     *
     * If no such entry existed to begin
     * with then one is created by combining
     * the input name (the one requested)
     * and the provided integral argument.
     *
     * Params:
     *   n_i = the name to lookup
     *   n_num = the integral argument
     * Returns: the mapped name
     */
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

/** 
 * The enumeration type
 * mapper has the ability
 * to consume a given
 * enum type and the name
 * of its member, afterwhich
 * it then returns a name
 * unique to that (Enum, name)
 * pair
 *
 * This is used by the C
 * emitter as enumeration
 * types need to have
 * completely unique 
 * member names (in C)
 */
public final class EnumMapper
{
    import niknaks.containers : Pool;
    private Pool!(EnumNameStore, Enum, false) _p;
    private size_t _roll;

    /** 
     * Returns the unique name
     * for the enum and name
     * pair
     *
     * Params:
     *   e = the `Enum`
     *   m = the member name
     * Returns: the generated name
     */
    public string getName(Enum e, string m)
    {
        scope(exit)
        {
            this._roll++;
        }

        EnumNameStore* _es = _p.pool(e);
        return _es.mapName(m, this._roll);
    }
}