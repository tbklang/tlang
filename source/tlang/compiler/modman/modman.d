module tlang.compiler.modman.modman;

import gogga;
import std.file : isDir;

// TODO: We may want to throw an exception whilst searching
// ... as to which path is invalid
import tlang.compiler.modman.exceptions;

// TODO: Rename to PathFinder or Searcher
// ... which is a more valid name

public struct ModuleEntry
{
    string filename;
    string moduleName;
}


/** 
 * Manager for searching for modules etc.
 */
public final class ModuleManager
{
    /** 
     * The search paths
     */
    private string[] searchPaths;

    /** 
     * Creates a new module manager with the
     * provided paths of which it should
     * consider when searching for module
     * files
     *
     * Params:
     *   searchPaths = the search paths
     * Throws:
     *   ModuleManagerError = if the
     * provided search paths are incorrect
     */
    this(string[] searchPaths)
    {
        if(!validate(searchPaths))
        {
            throw new ModuleManagerError(this, "An invalid path exists within the provided search paths");
        }

        this.searchPaths = searchPaths;
    }

    // Searches the given current directory 
    // ... and then all configured paths
    // ... returning `true` and setting `found`
    // ... in that case. Otherwise, nothing is
    // ... set and `false` is returned
    public bool search(string curModDir, string name, ref ModuleEntry found)
    {
        // Search given directory (recurse too)
        foreach(ModuleEntry mod; getModulesInDirectory(curModDir, true))
        {
            if(mod.moduleName == name)
            {
                found = mod;
                return true;
            }
        }

        // Search each of the search paths (on each, recurse)
        foreach(string path; this.searchPaths)
        {
            foreach(ModuleEntry mod; getModulesInDirectory(path, true))
            {
                if(mod.moduleName == name)
                {
                    found = mod;
                    return true;
                }
            }
        }


        return false;
    }


    import std.path;
    import std.file : dirEntries, DirEntry, SpanMode;
    import std.conv : to;
    import std.string : endsWith, strip, replace;
    // Use this to find all module entries from a given
    // module's own directory (like the directory
    // of the module doing the import)
    public ModuleEntry[] getModulesInDirectory(string directory, bool recurse = false)
    {
        ModuleEntry[] entries;

        scope(exit)
        {
            version(DBG_MODMAN)
            {
                gprintln("getModulesInDirectory("~directory~"): "~to!(string)(entries));
            }
        }

        foreach(DirEntry entry; dirEntries!()(directory, SpanMode.shallow))
        {
            // gprintln(entry);
            if(entry.isFile() && endsWith(entry.name(), ".t"))
            {
                string modulePath = absolutePath(entry.name());

                /** 
                 * If we have dir/
                 *     dir/a.t
                 *     dir/b.t
                 *
                 * Then we want just the last part of the path
                 * and without the file extension `.t`, therefpre
                 * we want:
                 * [a, b]
                 *
                 */
                string moduleName = pathSplitter(strip(entry.name(), ".t")).back();
                entries ~= ModuleEntry(modulePath, moduleName);
            }
            // If recursion is enabled
            else if(entry.isDir() && recurse)
            {
                // New base path
                version(DBG_MODMAN)
                {
                    gprintln("Recursing on "~to!(string)(entry)~"...");
                }

                
                ModuleEntry[] nestedMods = getModulesInDirectory(entry.name(), recurse);

                // Name must be relative to current directory/path
                foreach(ModuleEntry modEnt; nestedMods)
                {
                    modEnt.moduleName = pathSplitter(entry.name()).back()~"."~modEnt.moduleName;
                    gprintln(modEnt.moduleName);
                    // *(cast(char*)0) = 2;
                }


                entries ~= nestedMods;

                version(DBG_MODMAN)
                {
                    gprintln("Recursing on "~to!(string)(entry)~"... [done]");
                }
            }
        }

        return entries;
    }

    // import std.string : replace;
    // private static string slashToDot(string strIn)
    // {
    //     return replace(strIn, "/", ".");
    // }


    /** 
     * Validates the given paths, and only
     * returns a valid verdict if all of
     * the paths are valid search paths
     *
     * Params:
     *   searchPaths = the search paths
     * to consider
     * Returns: `true` if all paths are valid,
     * `false` otherwise
     */
    public static bool validate(string[] searchPaths)
    {
        foreach(string searchPath; searchPaths)
        {
            if(!validate(searchPath))
            {
                return false;
            }
        }

        return true;
    }

    /** 
     * Validates a given path that it is a valid
     * search path
     *
     * Params:
     *   searchPath = the path to check
     * Returns: `true` if the search path is valid,
     * `false` otherwise
     */
    public static bool validate(string searchPath)
    {
        // Path cannot be empty
        if(searchPath.length == 0)
        {
            return false;
        }

        // It should be a valid directory
        return isDir(searchPath);
    }
}

/**
 * Tests the static methods of the `ModuleManager`
 *
 * In this case positive verdict is expected
 */
unittest
{
    string[] goodPaths = [
        "source/tlang/testing",
        "source/tlang/testing/modules"
    ];

    bool res = ModuleManager.validate(goodPaths);
    assert(res);
}

/**
 * Tests the static methods of the `ModuleManager`
 *
 * In this case negative verdict is expected
 */
unittest
{
    string[] badPaths = [
        "source/tlang/testing",
        "source/tlang/testing/modules",
        "README.md",
    ];

    bool res = ModuleManager.validate(badPaths);
    assert(!res);
}


/**
 * Pretend that we importing modules
 * from a module `source/tlang/testing/modules/a.t`
 *
 * Let's see how we would resolve modules
 * from its point of view
 */
unittest
{
    
}