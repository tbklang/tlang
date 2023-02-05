module tlang.compiler.codegen.mapper.core;

import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import std.conv : to;
import gogga;

/** 
 * SymbolMapper
 *
 * Maps Entity's to consistent but unique symbol
 * names (strings)
 */
public class SymbolMapper
{
    // Used to map names to entities
    protected TypeChecker tc;

    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    public abstract string symbolLookup(Entity entityIn);
}

public enum SymbolMappingTechnique : string
{
    HASHMAPPER = "hashmapper",
    LEBANESE = "lebanese"
}