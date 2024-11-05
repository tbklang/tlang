/** 
 * Compiler configuration mechanism
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.configuration;

import tlang.compiler.core : CompilerException, CompilerError;
import std.string : cmp;

import niknaks.config : Registry;
public import niknaks.config : ConfigEntry;

/** 
 * Configuration registry
 * for a compiler
 */
public final class CompilerConfiguration
{
    private Registry reg;

    this()
    {
        reg.setAllowOverwrite(true);
    }

    /** 
     * Places the given value at
     * the provided name, overwiting
     * any previous entries if
     * already present
     *
     * Params:
     *   name = the entry's name
     *   value = the entry's value
     */
    public void addConfig(T)(string name, T value)
    {
        this.reg.newEntry(name, value);
    }

    /** 
     * Obtains the entry at the
     * given name
     *
     * Params:
     *   key = the entry's name
     * Returns: a `ConfigEntry`
     * Throws: 
     *   CompilerException if no
     * such entry exists
     */
    public ConfigEntry getConfig(string key)
    {
        ConfigEntry foundEntry;
        if(reg.getEntry_nothrow(key, foundEntry))
        {
            return foundEntry;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_KEY_NOT_FOUND);
        }
    }

    /** 
     * Checks if an entry at
     * the given name exists
     *
     * Params:
     *   key = the name to
     * check by
     * Returns: `true` if it
     * exists, `false` otherwise
     */
    public bool hasConfig(string key)
    {
        ConfigEntry _discard;
        return reg.getEntry_nothrow(key, _discard);
    }

    /** 
     * Generates the default compiler configuration
     *
     * Returns: a `CompilerConfguration`
     */
    public static CompilerConfiguration defaultConfig()
    {
        /* Generate a fresh new config */
        CompilerConfiguration config = new CompilerConfiguration();

        /* Enable Behaviour-C fixes (TODO: This should be changed to true before release) */
        config.addConfig("dgen:preinline_args", false);

        /* Enable pretty code generation for DGen */
        config.addConfig("dgen:pretty_code", true);

        /* Enable entry point test generation for DGen */
        config.addConfig("dgen:emit_entrypoint_test", true);

        /* Set the system C compiler for DGen to clang */
        config.addConfig("dgen:compiler", "clang");

        /**
         * Configure, at compile time, the system type aliases
         */
        version(X86)
        {
            /* Set maximum width to 4 bytes (32-bits) */
            config.addConfig("types:max_width", 4);
        }
        else version(X86_64)
        {
            /* Set maximum width to 8 bytes (64-bits) */
            config.addConfig("types:max_width", 8);
        }

        /**
         * Set the default search paths to be searched
         *
         * These paths are, namely, (TODO: should be /usr/lib/tlang/*)
         * sort of things here
         */
        string[] searchPaths = [];
        config.addConfig("modman:path", searchPaths);

        /**
         * If enabled then a module with
         * `module c;` must be named
         * `c.t`
         */
        // FIXME: Make true by default - this WILL break many unittests and semantic ones
        // so be very sure before you enable this
        config.addConfig("modman:strict_headers", false);
        
        /* Always warn about unused variables */
        config.addConfig("typecheck:warnUnusedVars", true);

        /* Always warn about unused functions */
        config.addConfig("typecheck:warnUnusedFuncs", true);

        return config;
    }
}