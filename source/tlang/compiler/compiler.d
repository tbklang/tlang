module compiler.compiler;

import gogga;
import std.conv : to;
import compiler.lexer;
import std.stdio : File;
import compiler.parsing.core;
import compiler.symbols.check;
import compiler.symbols.data;
import compiler.typecheck.core;
import compiler.typecheck.exceptions;
import core.stdc.stdlib;
import compiler.codegen.emit.core;
import compiler.codegen.emit.dgen;
import misc.exceptions : TError;
import compiler.codegen.mapper.core : SymbolMapper;
import compiler.codegen.mapper.hashmapper : HashMapper;
import compiler.codegen.mapper.lebanese : LebaneseMapper;
import std.string : cmp;

public enum CompilerError
{
    LEX_NOT_PERFORMED,
    NO_TOKENS,
    PARSE_NOT_YET_PERFORMED,
    TYPECHECK_NOT_YET_PERFORMED,
    CONFIG_ERROR,
    CONFIG_KEY_NOT_FOUND
}

public final class CompilerException : TError
{
    private CompilerError errType;

    this(CompilerError errType, string msg = "")
    {
        super("CompilerError("~to!(string)(errType)~")"~(msg.length ? ": "~msg : ""));
        this.errType = errType;
    }
}

public class CompilerConfiguration
{
    private string[string] config;

    public void setConfig(VType)(string key, VType value)
    {
        config[key] = to!(string)(value);
    }

    public VType getConfig(VType)(string key)
    {
        import std.algorithm : canFind;
        if(canFind(config.keys(), key))
        {
            return to!(VType)(config[key]);
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_KEY_NOT_FOUND);
        }
    }

    public bool hasConfig(string key)
    {
        string[] keys = config.keys();
        import std.algorithm.searching : canFind;

        return canFind(keys, key);
    }
}

public class Compiler
{
    /* The input source code */
    private string inputSource;

    /* The lexer */
    private Lexer lexer;

    /* The lexed tokens */
    private Token[] tokens;

    /* The parser */
    private Parser parser;
    private Module modulle;

    /* The typechecker/code generator */
    private TypeChecker typeChecker;

    /* The chosen code emitter to use */
    private CodeEmitter emitter;
    private File emitOutFile;

    /* The configuration */
    private CompilerConfiguration config;

    /* TODO: Make the default config */
    private void defaultConfig()
    {
        /* Enable Behaviour-C fixes */
        config.setConfig("behavec:preinline_args", true);

        /* Enable pretty code generation for DGen */
        config.setConfig("dgen:pretty_code", true);

        /* Enable entry point test generation for DGen */
        config.setConfig("dgen_emit_entrypoint_test", true);

        /* Set the mapping to hashing of entity names (TODO: This should be changed before release) */
        config.setConfig("emit:mapper", "hashmapper");
    }

    

    /** 
     * Create a new compiler instance to compile the given
     * source code
     * Params:
     *   sourceCode = the source code to compile
     */
    this(string sourceCode, File emitOutFile)
    {
        this.inputSource = sourceCode;
        this.emitOutFile = emitOutFile;

        this.config = new CompilerConfiguration();

        /* Enable the default config */
        defaultConfig();
    }

    /* Setup the lexer and begin lexing */
    public void doLex()
    {
        /* Setup the lexer and begin lexing */
        this.lexer = new Lexer(inputSource);
        this.lexer.performLex();

        this.tokens = this.lexer.getTokens();
    }

    public Token[] getTokens()
    {
        if(this.lexer is null)
        {
            throw new CompilerException(CompilerError.LEX_NOT_PERFORMED);
        }

        return tokens;
    }

    /* Spawn a new parser with the provided tokens */
    public void doParse()
    {
        Token[] lexedTokens = getTokens();

        if(lexedTokens.length == 0)
        {
            throw new CompilerException(CompilerError.NO_TOKENS);
        }
        else
        {
            /* Spawn a new parser with the provided tokens */
            this.parser = new Parser(lexedTokens);

            modulle = parser.parse();
        }
    }

    public Module getModule()
    {
        return modulle;
    }

    /** 
     * Spawn a new typechecker/codegenerator on the module
     * and perform type checking and code generation
     */
    public void doTypeCheck()
    {
        if(this.parser is null)
        {
            throw new CompilerException(CompilerError.PARSE_NOT_YET_PERFORMED);
        }

        this.typeChecker = new TypeChecker(modulle);

        /* Perform typechecking/codegen */
        this.typeChecker.beginCheck();
    }

    /* Perform code emitting */
    public void doEmit()
    {
        if(typeChecker is null)
        {
            throw new CompilerException(CompilerError.TYPECHECK_NOT_YET_PERFORMED);
        }

        if(!config.hasConfig("emit:mapper"))
        {
            throw new CompilerException(CompilerError.CONFIG_ERROR, "Missing a symbol mapper");
        }
        
        SymbolMapper mapper;
        string mapperType = config.getConfig!(string)("emit:mapper");

        if(cmp(mapperType, "hashmapper") == 0)
        {
            mapper = new HashMapper(typeChecker);
        }
        else if(cmp(mapperType, "lebanese") == 0)
        {
            mapper = new LebaneseMapper(typeChecker);
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_ERROR, "Invalid mapper type '"~mapperType~"'");
        }

        this.emitter = new DCodeEmitter(typeChecker, emitOutFile, config, mapper);
        emitter.emit(); // Emit the code
        emitOutFile.close(); // Flush (perform the write() syscall)
        emitter.finalize(); // Call CC on the file containing generated C code
    }

    public void compile()
    {
        /* Setup the lexer, perform the tokenization and obtain the tokens */
        doLex();

        /* Setup the parser with the provided tokens and perform parsing */
        doParse();

        /* Spawn a new typechecker/codegenerator on the module and perform type checking */
        doTypeCheck();

        /* Perform code emitting */
        doEmit();
    }
}

/** 
 * Performs compilation of the provided module(s)
 *
 * Params:
 *   sourceFiles = The module(s) to perform compilation with
 */
void beginCompilation(string[] sourceFiles)
{
    /* TODO: Begin compilation process, take in data here */
    gprintln("Compiling files "~to!(string)(sourceFiles)~" ...");

    foreach(string sourceFile; sourceFiles)
    {
        /* Read in the source code */
        // TODO: THis below code is used so many times, for heavens-sake please make a helper function for it
        gprintln("Reading source file '"~sourceFile~"' ...");
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

        /* The file to output to */
        File outFile;
        outFile.open("tlangout.c", "w");

        /* Create a new compiler */
        Compiler compiler = new Compiler(cast(string)fileBytes, outFile);
    
        /* Perform the compilation */
        compiler.compile();
    }
}

unittest
{
    // TODO: Add tests here for our `simple_<x>.t` tests or put them in DGen, I think here is better
    // FIXME: Crashes and I think because too fast or actually bad state? Maybe something is not being
    // cleared, I believe this may be what is happening
    // ... see issue #88
    // ... UPDATE: It seems to be any unit test..... mhhhh.
    // string[] testFiles = ["source/tlang/testing/simple_while.t"
    //                     ];

    //                     // "source/tlang/testing/simple_functions.t",
    //                     // "source/tlang/testing/simple_while.t",
    //                     // "source/tlang/testing/simple_for_loops.t",
    //                     // "source/tlang/testing/simple_cast.t",
    //                     // "source/tlang/testing/simple_conditionals.t",
    //                     // "source/tlang/testing/nested_conditionals.t",
    //                     // "source/tlang/testing/simple_discard.t"
    // foreach(string testFile; testFiles)
    // {
    //     beginCompilation([testFile]);
    // }
}