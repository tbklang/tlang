module tlang.compiler.modman.modman;

import gogga;

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
     *   
     */
    this(string[] searchPaths)
    {
        validate(searchPaths);
        this.searchPaths = searchPaths;
    }

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

        import std.file : isDir;

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

