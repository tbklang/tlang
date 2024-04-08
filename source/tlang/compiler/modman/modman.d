module tlang.compiler.modman.modman;

import tlang.misc.logging;
import std.file : isDir;
import std.path : isAbsolute;

import niknaks.arrays : isPresent;
import std.string : format;
import std.string : replace;

// TODO: We may want to throw an exception whilst searching
// ... as to which path is invalid
import tlang.compiler.modman.exceptions;

// TODO: Rename to PathFinder or Searcher
// ... which is a more valid name

import tlang.compiler.core;

import tlang.compiler.parsing.exceptions : SyntaxError;
import tlang.compiler.symbols.check : SymbolType, getSymbolType;
import tlang.compiler.lexer.core : Token;

import tlang.compiler.lexer.core;
import tlang.compiler.lexer.kinds.basic : BasicLexer;

import std.stdio : File;
import std.exception : ErrnoException;

import std.path;
import std.file : dirEntries, DirEntry, SpanMode;
import std.conv : to;
import std.string : endsWith, strip, replace;
import std.file : exists, isDir;

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

    /** 
     * Constructs a new module entry
     * from the given name and absolute
     * path to the module file itself
     *
     * Params:
     *   filename = the absolute opath
     * of the module itself
     *   moduleName = the module's name
     */
    this(string filename, string moduleName)
    {
        this.filename = filename;
        this.moduleName = moduleName;
    }
    
    /** 
     * Checks if the module entry
     * is valid which checks that
     * both the file path and name
     * have a length greater than `0`
     * and that the filepath is
     * an absolute path
     *
     * Returns: `true` if valid,
     * `false` otherwise
     */
    public bool isValid()
    {
        return moduleName.length && filename.length && isAbsolute(filename);
    }

    /** 
     * Obtains the oath to
     * the module's file
     *
     * Returns: the path
     */
    public string getPath()
    {
        return this.filename;
    }

    /** 
     * Obtains the module's name
     *
     * Returns: the name
     */
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
        // Add search paths discovered from configuration entry
        string[] cmdLinePaths = compiler.getConfig().getConfig("modman:path").getArray();
        addSearchPaths(cmdLinePaths);
        
        this.compiler = compiler;
    }

    /** 
     * Adds each of the provided paths
     * to the set of search paths
     *
     * Params:
     *   paths = the search path(s)
     * to add
     */
    public void addSearchPaths(string[] paths)
    {
        // Add each path
        foreach(string curCandidate; paths)
        {
            addSearchPath(curCandidate);
        }
    }

    /** 
     * Adds the given path to the set
     * of search paths
     *
     * Params:
     *   path = the path to add
     */
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

    /** 
     * Searches for a module entry
     * by the given name
     *
     * Params:
     *   modName = the name to search
     * for
     * Returns: a `ModuleEntry`
     * Throws:
     *    ModuleManagerError if no
     * such module entry could be
     * found
     */
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

    /** 
     * Searches for a module entry
     * by the given name
     *
     * Params:
     *   modName = the name to search
     * for
     *   found = the `ModuleEntry` found
     * (if so)
     * Returns: `true` if found, otherwise
     * `false`
     */
    public bool find(string modName, ref ModuleEntry found)
    {
        return find(this.searchPaths, modName, found);
    }

    /** 
     * Given a path to a directory this will
     * do a shallow search (stay within the directory)
     * for all files ending in `.t`, therefore
     * returning an array of all the absolute
     * paths to such files
     *
     * Params:
     *   directory = the directory path to search
     * Returns: an `string[]`
     */
    private static string[] findAllTFilesShallow(string directory)
    {
        string[] allTFiles;

        // The path must be valid
        if(!exists(directory))
        {
            gprintln(format("Skipping directory '%s' as it does not exist", directory), DebugType.WARNING);
            return null;
        }
        // The path must refer to a directory
        else if(!isDir(directory))
        {
            gprintln(format("Skipping directory '%s' it is a valid path but NOT a directory", directory), DebugType.WARNING);
            return null;
        }

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

    /** 
     * Given a dotted path this will
     * extract the last element
     *
     * Params:
     *   dottedPath = the dotted path
     * to derive from
     * Returns: the tail end
     */
    private static string tailEndGet(string dottedPath)
    {
        // Replace all `.`s with `/` such that we
        // can use the path splitter
        auto splitter = pathSplitter(replace(dottedPath, ".", "/"));

        // Get the tail-end side of the split
        string tailEnd = splitter.back();

        return tailEnd;
    }

    /** 
     * Searches the given directories 
     * Params:
     *   directories = paths to search
     *   modName = the module name
     * to search for
     *   found = the found `ModuleEntry`
     *   isDirect = in the case of not
     * finding the module in a shallow search
     * this controls if a nested search
     * should be conducted (default: `true`)
     * Returns: `true` if found, otherwise
     * `false`
     */
    private bool find(string[] directories, string modName, ref ModuleEntry found, bool isDirect = true)
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
            gprintln("Files ending in `.t`:\n\n"~dumpArray!(tFiles)(0, tFiles.length, 1));
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
             * Only consider searching in a nested
             * manner if the provided `modName`
             * contains `.`s in its name as these
             * are what will be used to perform the
             * nested search.
             *
             * If this is not the case then return
             * with nothing, else continue and calculate
             * the module's new short name by taking
             * the tail end of its name.
             */
            if(!isPresent(modName, '.'))
            {
                gprintln
                (
                    format
                    (
                        "Couldn't find the module named '%s' and no dots so nested search not being done",
                        modName
                    )
                );
                return false;
            }
            
            string newModName = tailEndGet(modName);
            gprintln("New module name "~newModName);

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
            foreach(string directory; directories)
            {
                /** 
                 * Replace `bruh.c` into `bruh/c`
                 *
                 * First replace all `.`'s with `/`.
                 * 
                 * Set new module name to `c` (`back()`)
                 * and make relativeDir `bruh/` (`popBack()`)
                 */
                auto splitter = pathSplitter(replace(modName, ".", "/"));
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

            return find(newPaths, newModName, found, false);
        }

        return false;
    }

    
    /** 
     * Given an expected symbol and the
     * actual token that was received
     * this compares the types of both
     * to one another, if equal
     * then nothing is done, otherwise
     * and exception is thrown
     *
     * Params:
     *   expected = the expected
     * `SymbolType`
     *   got = the received `Token`\
     * Throws:
     *   SyntaxError if there is a
     * mismatch
     */
    private static expect(SymbolType expected, Token got)
    {
        SymbolType actualType = getSymbolType(got);

        if(actualType != expected)
        {
            // TODO: Make SyntaxError have a parser-less version for null-safety in the future
            throw new SyntaxError(null, expected, got);
        }
    }

    /** 
     * Given a mdoule entry this
     * will read all of its bytes
     *
     * Params:
     *   ent = the module entry
     * Returns: the contents
     * Throws:
     *   ModuleManagerError if no
     * such module could be opened
     */
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
    
    /** 
     * Given a module entry this
     * will read all of its bytes
     *
     * Params:
     *   ent = the module entry
     *   source = the retrieved bytes
     * Returns: `true` if the read
     * succeeded, `false` otherwise
     */
    private static bool readModuleData(ModuleEntry ent, ref string source)
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
    private static bool validate(string[] searchPaths)
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
    private static bool validate(string searchPath)
    {
        // Path cannot be empty
        if(searchPath.length == 0)
        {
            return false;
        }

        // Path should exist AND it should be a valid directory
        return exists(searchPath) && isDir(searchPath);
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