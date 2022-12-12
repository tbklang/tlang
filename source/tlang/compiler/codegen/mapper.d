module compiler.codegen.mapper;

import compiler.typecheck.core;
import compiler.symbols.data;

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

    public static string symbolLookup(Container container, string entityNameIn)
    {
        // Firstly translate the entity name to the full absolute path
        auto entity = tc.getResolver().resolveBest(container, entityNameIn); //TODO: Remove `auto`
        string entityNameAbsolute = tc.getResolver().generateName(tc.getModule(), entity);

        // Hash the absolute path name
        // FIXME: Ensure these hashes are unique (use the smbyol table!)
        import std.digest : toHexString, LetterCase;
        import std.digest.md : md5Of;

        // Generate the name as `_<hexOfAbsPath>`
        string symbolName = toHexString!(LetterCase.lower)(md5Of(entityNameAbsolute));
        symbolName="_"~symbolName;

        return symbolName;
    }


}