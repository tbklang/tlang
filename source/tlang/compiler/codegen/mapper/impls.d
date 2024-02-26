module tlang.compiler.codegen.mapper.impls;

import tlang.compiler.codegen.mapper.api;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.data : Entity;

public class LebanonMapper : SymbolMapperV2
{
    private TypeChecker tc;

    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    public string map(Entity item, ScopeType type)
    {
        // Generate the root name for this item
        string absolutePath = tc.getResolver().generateName(tc.getProgram(), item);

        // Replace all `.`'s with underscores
        import std.string : replace;
        string mappedSymbol = replace(absolutePath, ".", "_");

        return mappedSymbol;
    }
}

public class HashMapper : SymbolMapperV2
{
    private TypeChecker tc;
    
    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    public string map(Entity item, ScopeType type)
    {
        // TODO: Implement me
        return null;
    }
}