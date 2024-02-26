module tlang.compiler.codegen.mapper.impls;

import tlang.compiler.codegen.mapper.api;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.data : Entity;
import tlang.compiler.symbols.containers : Module;

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
            // Determine the module this entity is contained within
            Module modCon = cast(Module)this.tc.getResolver().findContainerOfType(Module.classinfo, item);

            // Generate absolute path (but without the `<moduleName>.[..]`)
            // rather only everything after the first dot
            string p = tc.getResolver().generateName(modCon, item);
            import std.string : split, join;
            string[] components = split(p, ".")[1..$];
            
            // Join them back up with periods
            path = join(components, ".");
        }
        

        // Replace all `.`'s with underscores
        import std.string : replace;
        string mappedSymbol = replace(path, ".", "_");

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

        // Generate the name as `_<hex(<path>)>`
        import std.digest : toHexString, LetterCase;
        import std.digest.md : md5Of;
        string mappedSymbol = toHexString!(LetterCase.lower)(md5Of(path));

        return mappedSymbol;
    }
}