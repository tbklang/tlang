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
        string path;
        if(type == ScopeType.GLOBAL)
        {
            // Generate the root name for this item
            path = tc.getResolver().generateName(tc.getProgram(), item);
        }
        else
        {
            // TODO: Implement me
            // TODO: May need to take in a `Container` (for top-level)
            // path = tc.getResolver().generateName()
        }
        

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