module tlang.compiler.core;

import gogga;
import std.conv : to;
import tlang.compiler.lexer.core2 : LexerInterface;
import tlang.compiler.lexer.basic : BasicLexer;
import tlang.compiler.lexer.tokens : Token;
import std.stdio : File;
import tlang.compiler.parsing.core;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.typecheck.core;
import tlang.compiler.typecheck.exceptions;
import core.stdc.stdlib;
import tlang.compiler.codegen.emit.core;
import tlang.compiler.codegen.emit.dgen;
import misc.exceptions : TError;
import tlang.compiler.codegen.mapper.core : SymbolMapper;
import tlang.compiler.codegen.mapper.hashmapper : HashMapper;
import tlang.compiler.codegen.mapper.lebanese : LebaneseMapper;
import std.string : cmp;
import tlang.compiler.configuration : CompilerConfiguration, ConfigEntry;

// TODO: Add configentry unittests

/** 
 * The sub-error type of `CompilerException`
 */
public enum CompilerError
{
    /** 
     * Occurs when tokens are requested but
     * the tokenization process has not yet
     * occurred
     */
    LEX_NOT_PERFORMED,

    /** 
     * Occurs if the tokenization process resulted
     * in zero tokens being produced
     */
    NO_TOKENS,

    /** 
     * Occurs if typechecking is performed
     * but no module was produced due to
     * parsing not yet being performed
     */
    PARSE_NOT_YET_PERFORMED,

    /** 
     * Occurs if emit was called but no
     * code queue wa sproduced due to
     * typechecking not being performed
     * yet
     */
    TYPECHECK_NOT_YET_PERFORMED,

    /** 
     * Occurs on a configuration error
     */
    CONFIG_ERROR,

    /** 
     * Occurs if a configuration key cannot
     * be found
     */
    CONFIG_KEY_NOT_FOUND,
    
    /** 
     * Occurs when the type of the configuration
     * key requested does not match its actual type
     */
    CONFIG_TYPE_ERROR,

    /** 
     * Occurs when a duplicate configuration key
     * entry is attempted to be created
     */
    CONFIG_DUPLICATE_ENTRY
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

public class Compiler
{
    /* The input source code */
    private string inputSource;

    /* The lexer */
    private LexerInterface lexer;

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
        config.addConfig(ConfigEntry("behavec:preinline_args", true));

        /* Enable pretty code generation for DGen */
        config.addConfig(ConfigEntry("dgen:pretty_code", true));

        /* Enable entry point test generation for DGen */
        config.addConfig(ConfigEntry("dgen:emit_entrypoint_test", true));

        /* Set the mapping to hashing of entity names (TODO: This should be changed before release) */
        config.addConfig(ConfigEntry("emit:mapper", "hashmapper"));
    }

    public CompilerConfiguration getConfig()
    {
        return config;
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
        this.lexer = new BasicLexer(inputSource);
        (cast(BasicLexer)(this.lexer)).performLex();

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
            /* Spawn a new parser with the lexer (token source) */
            this.parser = new Parser(lexer);

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
        string mapperType = config.getConfig("emit:mapper").getText();

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

