/**
 * `size_t` and `ssize_t` support
 *
 * This module contains the required lookup
 * mechanisms to support these compile-time-dynamic
 * types
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */ 
module tlang.compiler.typecheck.size_t;

import tlang.compiler.configuration : CompilerConfiguration;

/** 
 * Determines if the given type is a system type alias
 *
 * Params:
 *   typeAlias = the type to check
 * Returns: `true` if system type alias, `false` otherwise
 */
public bool isSystemType(string typeAlias)
{
    /* `size_t`/`ssize_t` system type aliases */
    if(typeAlias == "size_t" || typeAlias == "ssize_t")
    {
        return true;
    }
    /* Else, not a system type alias */
    else
    {
        return false;
    }
}

/** 
 * Given a type alias (think `size_t`/`ssize_t` for example) this will
 * look up in the compiler's configuration what that size should be
 * resolved to
 *
 * Params:
 *   compilerConfig = the compiler's configuration
 *   typeAlias = the system type alias to lookup
 * Returns: the concrete type
 */
public string getSystemType(CompilerConfiguration compilerConfig, string typeAlias)
{
    /* Determine machine's width */
    ulong maxWidth = compilerConfig.getConfig("types:max_width").numeric();

    string maxType;

    if(maxWidth == 1)
    {
        if(typeAlias == "size_t")
        {
            return "ubyte";
        }
        else if(typeAlias == "ssize_t")
        {
            return "byte";
        }
        else
        {
            assert(false);  
        }
    }
    else if(maxWidth == 2)
    {
        if(typeAlias == "size_t")
        {
            return "ushort";
        }
        else if(typeAlias == "ssize_t")
        {
            return "short";
        }
        else
        {
            assert(false);  
        }
    }
    else if(maxWidth == 4)
    {
        if(typeAlias == "size_t")
        {
            return "uint";
        }
        else if(typeAlias == "ssize_t")
        {
            return "int";
        }
        else
        {
            assert(false);  
        }
    }
    else if(maxWidth == 8)
    {
        if(typeAlias == "size_t")
        {
            return "ulong";
        }
        else if(typeAlias == "ssize_t")
        {
            return "long";
        }
        else
        {
            assert(false);  
        }
    }
    else
    {
        assert(false);
    }
}