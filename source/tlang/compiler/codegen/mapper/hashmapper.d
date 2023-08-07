module tlang.compiler.codegen.mapper.hashmapper;

import tlang.compiler.codegen.mapper.core : SymbolMapper;
import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import std.array : split, join;

public final class HashMapper : SymbolMapper
{

    this(TypeChecker tc)
    {
        super(tc);
    }

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
    public override string symbolLookup(Entity entityIn)
    {
        // Generate the absolute full path of the Entity
        string absoluteFullPath = tc.getResolver().generateNameBest(entityIn);

        // Symbol mapped name
        string symbolName;

        scope(exit)
        {
            import gogga;
            gprintln("symbolLookup: absPath '"~absoluteFullPath~"'");
            gprintln("symbolLookup: mappedPath '"~symbolName~"'");
        }

        // Hash the absolute path name
        // FIXME: Ensure these hashes are unique (use the smbyol table!)
        import std.digest : toHexString, LetterCase;
        import std.digest.md : md5Of;

        // Generate the name as `_<hexOfAbsPath>`
        symbolName = toHexString!(LetterCase.lower)(md5Of(absoluteFullPath));
        symbolName="t_"~symbolName;

        return symbolName;
    }

    /** 
     * Given the absolute path this will scan each segment
     * of said path until it finds (if any) a `StructInstanceVariable`
     * upon which point it will return `true` and also set the `pathToIt`
     * parameter to the path up till (and including) that point
     *
     * Params:
     *   absPath = the absolute path to scan
     *   pathToIt = this is set to the path of the found `StructVariableInstance`
     * on the occasion one is foundm else left untouched
     * Returns: `true` if found, `false` otherwise
     */
    private bool containsStructVarInstanceRefAlongTheWay(string absPath, ref string pathToIt)
    {
        string[] segments = split(absPath, ".");
        string curPath;
        string[] segBuild;
        foreach(string segment; segments)
        {
            segBuild ~= segment;
            curPath = join(segBuild, ".");
            Entity segmentEntity = tc.getResolver().resolveBest(tc.getModule(), curPath);

            if(cast(StructVariableInstance)segmentEntity)
            {
                pathToIt = curPath;
                return true;
            }
        }

        // TODO: Implement me
        return false;
    }
}