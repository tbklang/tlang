module tlang.compiler.modman.modman;

import gogga;
import std.file : isDir;

// TODO: We may want to throw an exception whilst searching
// ... as to which path is invalid
import tlang.compiler.modman.exceptions;

// TODO: Rename to PathFinder or Searcher
// ... which is a more valid name

import tlang.compiler.core;

/** 
 * Represents the module-name to
 * file path mapping
 */
public struct ModuleEntry
{
    /** 
     * Absolute path to the module's file
     */
    string filename;

    /** 
     * The module's name
     */
    string moduleName;
}


/** 
 * Manager for searching for modules etc.
 */
public final class ModuleManager
{
    /** 
     * The compiler instance
     */
    private Compiler compiler;

    /** 
     * The search paths
     */
    private string[] searchPaths;

    /** 
     * Creates a new module manager with the
     * provided compiler such that we can
     * discover things such the search paths
     * to be considered
     *
     * Params:
     *   compiler = the compiler instance
     * to use for various informations
     * Throws:
     *   ModuleManagerError = if the
     * provided search paths are incorrect
     */
    this(Compiler compiler)
    {
        // Add all command-line search paths
        string[] cmdLinePaths = compiler.getConfig().getConfig("modman:path").getArray();
        addSearchPaths(cmdLinePaths);
        
        this.compiler = compiler;
    }

    public void addSearchPaths(string[] paths)
    {
        // Add each path
        foreach(string curCandidate; paths)
        {
            addSearchPath(curCandidate);
        }
    }


    public void addSearchPath(string path)
    {
        // Obtain absolute path
        string absPath = absolutePath(path);

        // Only add if not present
        foreach(string curPath; this.searchPaths)
        {
            if(curPath == path)
            {
                return;
            }
        }

        // Check that the path is valid
        if(!validate(path))
        {
            throw new ModuleManagerError(this, "The provided search path '"~path~"' is invalid");
        }

        // Add path
        this.searchPaths ~= absPath;
    }


    public ModuleEntry[] entries()
    {
        // TODO: Now now do searchPath+cwd (but it should be path to command-line modules: Compiler must be updated for that)
        import std.file : getcwd;
        string[] searchPathsConcrete = this.searchPaths~[getcwd()];

        return entries(searchPathsConcrete);
    }


    public ModuleEntry searchFrom_throwable(string searchQuery, string initialModulePath)
    {
        ModuleEntry foundEntry;

        if(searchFrom(searchQuery, initialModulePath, foundEntry))
        {
            return foundEntry;
        }
        else
        {
            throw new ModuleManagerError(this, "Could not find module '"~searchQuery~"'");
        }
    }

    public bool searchFrom(string searchQuery, string initialModulePath, ref ModuleEntry foundEntry)
    {
        // Get the directory name
        string initialModuleContainingDirectory = dirName(initialModulePath);

        // Grab all module entry's reachable from that path
        // and also the default search paths
        string[] considerPaths = this.searchPaths~[initialModuleContainingDirectory];
        ModuleEntry[] contDirMods = entries(considerPaths);

        // Now try to match by module name
        foreach(ModuleEntry curModEnt; contDirMods)
        {
            if(curModEnt.moduleName == searchQuery)
            {
                foundEntry = curModEnt;
                return true;
            }
        }

        return false;
    }


    // TODO: In future, allow adding a search path,
    // then just call it normally

    // TODO: I am using this for testing but it may be useful
    // ... as an entry point.
    // 
    // Recall `rdmd a.d` finding `b.d` relative to the
    // path to `a.d` and the directory it lay within
    public ModuleEntry[] entriesWithInitial(string initialModulePath)
    {
        import std.file : getcwd;
        string[] searchPathsConcrete = this.searchPaths~[];

        // But now tack on the directory of the path to the module
        auto splitterino = pathSplitter(initialModulePath);
        splitterino.popBack();
        import std.range : array;
        import std.string : join;
        string initialModuleDirectory = join(array(splitterino), "/");

        // TODO: Enable
        // version(DBG_MODMAN)
        // {
            gprintln("Initial module directory: "~initialModuleDirectory);
        // }
        searchPathsConcrete ~= [initialModuleDirectory];

        // TODO: Enab;e
        // version(DBG_MODMAN)
        // {
            gprintln("Using search paths: "~to!(string)(searchPathsConcrete));
        // }

        return entries(searchPathsConcrete);
    }


    public ModuleEntry[] entries(string[] directories)
    {
        ModuleEntry[] foundEntries;

        // Consider each directory
        foreach(string directory; directories)
        {
            // Enumrate all directory entries in `directory`
            foreach(DirEntry entry; dirEntries!()(directory, SpanMode.shallow))
            {
                // If it is a file and ends with `.t` file extension
                if(entry.isFile() && endsWith(entry.name(), ".t"))
                {
                    // Obtain the absolute path to the file
                    string modulePath = absolutePath(entry.name());

                    // The module's name (will be parsed off the module's
                    // ... header)
                    string moduleName;

                    // Parse module's header
                    if(!skimModuleDeclaredName(modulePath, moduleName))
                    {
                        // TODO: Handle this error
                        // TODO: nextToken() should throw exception when it runs out
                        throw new ModuleManagerError(this, "Error parsing module header for '"~modulePath~"'");
                    }

                    // TODO: Enable
                    // version(DBG_MODMAN)
                    // {
                        gprintln("Skimmed '"~to!(string)(modulePath)~"' to '"~moduleName~"'");
                    // }

                    // Create and add entry
                    ModuleEntry modEnt = ModuleEntry(modulePath, moduleName);
                    foundEntries ~= modEnt;
                }
                // If it is a directory, recusrse
                else if(entry.isDir())
                {
                    // Recurse and discover
                    ModuleEntry[] nestedMods = entries([entry.name()]);

                    // Add all discovered entries
                    foundEntries ~= nestedMods;
                }
            }
            
        }

        return foundEntries;
    }


    import tlang.compiler.parsing.exceptions : SyntaxError;
    import tlang.compiler.symbols.check : SymbolType, getSymbolType;
    import tlang.compiler.lexer.core : Token;

    public static expect(SymbolType expected, Token got)
    {
        SymbolType actualType = getSymbolType(got);

        if(actualType != expected)
        {
            // TODO: Make SyntaxError have a parser-less version for null-safety in the future
            throw new SyntaxError(null, expected, got);
        }
    }

    /** 
     * Given a path to a module file, this will open it
     * up, read its header and therefore derived the
     * module's name based off of that
     *
     * Params:
     *   modulePath = the path to the module file
     *   skimmedName = the name found (if any)
     * Returns: `true` if successfully skimmed,
     * `false` otherwise
     */
    private bool skimModuleDeclaredName(string modulePath, ref string skimmedName)
    {
        import tlang.compiler.lexer.core;
        import tlang.compiler.lexer.kinds.basic : BasicLexer;

        gprintln("Begin skim for: "~modulePath);

        try
        {
            string declaredName;

            string moduleSourceCode = gibFileData(modulePath); // TODO: check for IO exception
            LexerInterface lexer = new BasicLexer(moduleSourceCode);
            (cast(BasicLexer)(lexer)).performLex();

            /* Expect `module` and module name and consume them (and `;`) */
            expect(SymbolType.MODULE, lexer.getCurrentToken());
            lexer.nextToken();

            /* Module name may NOT be dotted (TODO: Maybe it should be yeah) */
            expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
            declaredName = lexer.getCurrentToken().getToken();
            lexer.nextToken();

            /* Expect an ending semi colon */
            expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
            lexer.nextToken();

            // Save the name
            skimmedName = declaredName;

            return true;
        }
        catch(LexerException e)
        {
            return false;
        }
    }

    import std.path;
    import std.file : dirEntries, DirEntry, SpanMode;
    import std.conv : to;
    import std.string : endsWith, strip, replace;
    
    private static string slashToDot(string strIn)
    {
        return replace(strIn, "/", ".");
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