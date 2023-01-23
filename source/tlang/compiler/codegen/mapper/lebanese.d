module compiler.codegen.mapper.lebanese;

import compiler.codegen.mapper.core : SymbolMapper;
import compiler.typecheck.core;
import compiler.symbols.data;
import std.string : replace;

public final class LebaneseMapper : SymbolMapper
{
    this(TypeChecker tc)
    {
        super(tc);
    }

    /** 
     * Maps given Entity's name to a version whereby all the
     * `.`'s are placed by underscores preceded by a `t_`
     *
     * Params:
     *   entityIn = the Entity to map
     * Returns: A string of the mapped symbol
     */
    public override string symbolLookup(Entity entityIn)
    {
        // Generate the absolute full path of the Entity
        string absoluteFullPath = tc.getResolver().generateNameBest(entityIn);

        // Generate the name as `_<underscored>`
        string symbolName = replace(absoluteFullPath, ".", "_");
        symbolName="t_"~symbolName;

        return symbolName;
    }
}