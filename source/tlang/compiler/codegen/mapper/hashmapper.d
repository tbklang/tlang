module tlang.compiler.codegen.mapper.hashmapper;

import tlang.compiler.codegen.mapper.core : SymbolMapper;
import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;

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