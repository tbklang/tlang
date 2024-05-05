/**
 * Various implementations of different
 * symbol mapping techniques
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.mapper.impls;

import tlang.compiler.codegen.mapper.core;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.data : Entity;
import tlang.compiler.symbols.containers : Module;
import std.string : format;

/** 
 * The lebanese smbol mapper
 */
public class LebanonMapper : SymbolMapper
{
    /** 
     * For access to the resolver
     */
    private TypeChecker tc;

    /** 
     * Constructs a new lebanese
     * symbol mapper
     *
     * Params:
     *   tc = the `TypeChecker`
     * to use
     */
    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    /** 
     * Maps the given `Entity` to a symbol
     * name with the provided scope type
     *
     * Params:
     *   item = the entity to generate a
     * symbol name for
     *   type = the `ScopeType` to map
     * using
     * Returns: the symbol name
     */
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

version(unittest)
{
    import std.stdio : File;
    import tlang.compiler.core : Compiler;
    import tlang.compiler.symbols.data : Program, Module, Variable;
    import std.string : cmp, format;
    import std.stdio : writeln;
}

unittest
{
    File dummyOut;
    Compiler compiler = new Compiler("", "", dummyOut);

    Program program = new Program();
    compiler.setProgram(program);

    Module mod = new Module("modA");
    program.addModule(mod);

    Variable variable = new Variable("int", "varA");
    variable.parentTo(mod);
    mod.addStatement(variable);

    TypeChecker tc = new TypeChecker(compiler);

    SymbolMapper lebMapper = new LebanonMapper(tc);
    
    string withModPath = lebMapper.map(variable, ScopeType.GLOBAL);
    writeln(format("withModPath: '%s'", withModPath));
    assert(cmp(withModPath, "modA_varA") == 0);

    string withoutModPath = lebMapper.map(variable, ScopeType.LOCAL);
    writeln(format("withoutModPath: '%s'", withoutModPath));
    assert(cmp(withoutModPath, "varA") == 0);
}

/** 
 * The hash-based mapper
 */
public class HashMapper : SymbolMapper
{
    /** 
     * For access to the resolver
     */
    private TypeChecker tc;
    
    /** 
     * Constructs a new hash
     * symbol mapper
     *
     * Params:
     *   tc = the `TypeChecker`
     * to use
     */
    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    /** 
     * Maps the given `Entity` to a symbol
     * name with the provided scope type
     *
     * Params:
     *   item = the entity to generate a
     * symbol name for
     *   type = the `ScopeType` to map
     * using
     * Returns: the symbol name
     */
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

        // Generate the name as `_<hex(<path>)>`
        import std.digest : toHexString, LetterCase;
        import std.digest.md : md5Of;
        string mappedSymbol = format("t_%s", toHexString!(LetterCase.lower)(md5Of(path)));

        return mappedSymbol;
    }
}

unittest
{
    File dummyOut;
    Compiler compiler = new Compiler("", "", dummyOut);

    Program program = new Program();
    compiler.setProgram(program);

    Module mod = new Module("modA");
    program.addModule(mod);

    Variable variable = new Variable("int", "varA");
    variable.parentTo(mod);
    mod.addStatement(variable);

    TypeChecker tc = new TypeChecker(compiler);

    SymbolMapper hashMapper = new HashMapper(tc);
    
    string withModPath = hashMapper.map(variable, ScopeType.GLOBAL);
    writeln(format("withModPath: '%s'", withModPath));
    writeln("withModPath", withModPath);
    assert(cmp(withModPath, "t_ecec68ed63440cb8a3eeb8ced54dfd14") == 0);

    string withoutModPath = hashMapper.map(variable, ScopeType.LOCAL);
    writeln(format("withoutModPath: '%s'", withoutModPath));
    assert(cmp(withoutModPath, "t_6afa5299740148c1e32a213f880cec3b") == 0);
}