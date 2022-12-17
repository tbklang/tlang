module compiler.codegen.mapper;

import compiler.typecheck.core;
import compiler.symbols.data;
import std.conv : to;
import gogga;

/** 
 * SymbolMapper
 *
 * Maps Entity's to consistent but unique symbol
 * names (strings)
 */
public final class SymbolMapper
{
    // Used to map names to entities
    public static TypeChecker tc;

    // Entity map
    // private string[Entity] symbolMap;

    // this(TypeChecker tc)
    // {
    //     this.tc = tc;
    // }

    /** 
     * Given an Entity this will generate a unique (but consistent)
     * symbol name for it by taking the md5 hash of the full absolute
     * path to the Entity and finally prefixing it with <code>t_</code>.
     *
     * Params:
     *   entityIn = The Entity to generate a hash for
     *
     * Returns: The symbol hash
     */
    public static string symbolLookup(Entity entityIn)
    {
        // Generate the absolute full path of the Entity
        string absoluteFullPath = tc.getResolver().generateNameBest(entityIn);

        // Hash the absolute path name
        // FIXME: Ensure these hashes are unique (use the smbyol table!)
        import std.digest : toHexString, LetterCase;
        import std.digest.md : md5Of;

        // Generate the name as `_<hexOfAbsPath>`
        string symbolName = toHexString!(LetterCase.lower)(md5Of(absoluteFullPath));
        symbolName="t_"~symbolName;

        return symbolName;
    }
}