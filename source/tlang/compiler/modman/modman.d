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
    private string filename;

    /** 
     * The module's name
     */
    private string moduleName;

    this(string filename, string moduleName)
    {
        this.filename = filename;
        this.moduleName = moduleName;
    }
    
    public bool isValid()
    {
        import std.path : isAbsolute;
        return moduleName.length && filename.length && isAbsolute(filename);
    }

    public string getPath()
    {
        return this.filename;
    }

    public string getName()
    {
        return this.moduleName;
    }

    /** 
     * Checks if the current module entry
     * is equal to the other by means of
     * comparison of their file paths
     *
     * Params:
     *   rhs = the module to compare to
     * Returns: `true` if equal, otherwise
     * `false`
     */
    public bool opEquals(ModuleEntry rhs)
    {
        return this.filename == rhs.filename;
    }
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

    public ModuleEntry find(string modName)
    {
        ModuleEntry foundEntry;

        if(find(modName, foundEntry))
        {
            return foundEntry;
        }
        else
        {
            throw new ModuleManagerError(this, "Could not find module '"~modName~"'");
        }
    }

    public bool find(string modName, ref ModuleEntry found)
    {
        return find(this.searchPaths, modName, found);
    }

    public static string[] findAllTFilesShallow(string directory)
    {
        string[] allTFiles;


        // Enumrate all directory entries in `directory`
        foreach(DirEntry entry; dirEntries!()(directory, SpanMode.shallow))
        {
            // If it is a file and ends with .t
            if(entry.isFile() && endsWith(entry.name(), ".t"))
            {
                // Obtain the absolute path to the file and save it
                allTFiles~=absolutePath(entry.name());
            }
        }

        return allTFiles;
    }

    public bool find(string[] directories, string modName, ref ModuleEntry found, bool isDirect = true)
    {
        gprintln("Request to find module '"~modName~"' in directories: "~to!(string)(directories));

        // Discover all files ending in .t in all search paths
        // (Doing shallow)
        string[] tFiles;
        foreach(string directory; directories)
        {
            tFiles ~= findAllTFilesShallow(directory);
        }

        version(DBG_MODMAN)
        {
            import niknaks.debugging : dumpArray;
            gprintln("Files ending in `.t`:\n\n"~dumpArray(tFiles, 0, tFiles.length, 1));
        }


        /**
         * Try to see if we can find our module immediately
         * in any of the search paths (directly, no recursed
         * down)
         */
        foreach(string tFile; tFiles)
        {
            // Potential module name (based off of stripping `.t` file extension)
            // ... and also removing the path trail
            auto splitter = pathSplitter(strip(tFile, ".t"));
            string modNamePot = splitter.back();

            // If it matches directly, then return a found entry
            if(modNamePot == modName)
            {
                found = ModuleEntry(tFile, modNamePot);
                return true;
            }

            gprintln("Original path: "~tFile);
            gprintln("Module name potetial: '"~modNamePot~"'");
        }

        // Only if not tried already (else recursion)
        if(isDirect)
        {
            /**
            * Now before giving up we must consider
            * using the module name's which have
            * dots in them use those as relative
            * path indicators.
            *
            * For this we begin the scan of all
            * the directories BUT we tack on
            * the relative path to each
            */
            string[] newPaths;
            string newModName;
            foreach(string directory; directories)
            {
                // Only consider module names with dots in them
                import niknaks.arrays : isPresent;
                if(isPresent(modName, '.'))
                {
                    // Construct relative directory (replace `.` with `/`)
                    // and also remove the file part

                    /** 
                     * Replace `bruh.c` into `bruh/c`
                     *
                     * First replace all `.`'s with `/`.
                     * 
                     * Set new module name to `c` (`back()`)
                     * and make relativeDir `bruh/` (`popBack()`)
                     */
                    import std.string : replace;
                    auto splitter = pathSplitter(replace(modName, ".", "/"));

                    newModName = splitter.back();
                    gprintln("New module name (ultra-back): "~newModName);

                    splitter.popBack();


                    string relativeDir;
                    foreach(string element; splitter)
                    {
                        relativeDir ~= element ~"/";
                    }
                    

                    gprintln("Relative dir (generated): "~relativeDir);

                    // Construct the directory to search
                    string newSearchPath = directory~"/"~relativeDir;
                    gprintln("New search path (consideration): "~newSearchPath);

                    newPaths ~= newSearchPath;
                }
                
            }

            return find(newPaths, newModName, found, false);
        }

        


        return false;
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


    public string readModuleData_throwable(ModuleEntry ent)
    {
        string source;

        if(readModuleData(ent, source))
        {
            return source;
        }
        else
        {
            throw new ModuleManagerError(this, "Could not open module '"~ent.moduleName~"' at '"~ent.filename~"' for reading");
        }
    }

    import std.stdio;
    import std.exception : ErrnoException;
    public static bool readModuleData(ModuleEntry ent, ref string source)
    {
        File modFile;

        scope(exit)
        {
            if(modFile.isOpen())
            {
                modFile.close();
            }
        }

        try
        {
            modFile.open(ent.filename, "rb");

            byte[] data;
            data.length = modFile.size();
            data = modFile.rawRead(data);

            source = cast(string)data;

            return true;
        }
        catch(ErrnoException e)
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