module tlang.compiler.core;

import gogga;
import std.conv : to;
import tlang.compiler.lexer.core;
import tlang.compiler.lexer.kinds.basic : BasicLexer;
import std.stdio : File;
import tlang.compiler.parsing.core;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.typecheck.core;
import tlang.compiler.typecheck.exceptions;
import core.stdc.stdlib;
import tlang.compiler.codegen.emit.core;
import tlang.compiler.codegen.emit.dgen;
import misc.exceptions;
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

    /* Input file path */
    private string inputFilePath;

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


    public CompilerConfiguration getConfig()
    {
        return config;
    }

    /** 
     * Create a new compiler instance to compile the given
     * source code
     *
     * Params:
     *   sourceCode = the source code to compile

     */
    this(string sourceCode, string inputFilePath, File emitOutFile)
    {
        this.inputSource = sourceCode;
        this.inputFilePath = inputFilePath;
        this.emitOutFile = emitOutFile;
        
        /* Get the default config */
        this.config = CompilerConfiguration.defaultConfig();
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
            /* Spawn a new parser with the provided tokens */
            this.parser = new Parser(lexer);

            modulle = parser.parse(this.inputFilePath);
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

        this.typeChecker = new TypeChecker(modulle, config);

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

        if(!config.hasConfig("dgen:mapper"))
        {
            throw new CompilerException(CompilerError.CONFIG_ERROR, "Missing a symbol mapper");
        }
        
        SymbolMapper mapper;
        string mapperType = config.getConfig("dgen:mapper").getText();

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

// TODO: Move the below to utils
// TODO: Make it do error checking on the  path provided and file-access rights
/** 
 * Opens the source file at the given path, reads the data
 * and returns it
 *
 * Params:
 *   sourceFile = the path to the file to open
 * Returns: the source data
 */
public string gibFileData(string sourceFile)
{
    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    return cast(string)fileBytes;
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
        Compiler compiler = new Compiler(cast(string)fileBytes, sourceFile, outFile);
    
        /* Perform the compilation */
        compiler.compile();
    }
}

/**
 * Tests the following pipeline:
 *
 * 1. lexing -> parsing -> typecheck/codegen -> emit (DGen)
 *
 * Kinds of tests:
 * 
 * 1. Positive tests (must pass)
 */
unittest
{
    // TODO: Ensure up to date with d.yml
    string[] testFiles = [
                        "source/tlang/testing/simple_functions.t",
                        "source/tlang/testing/simple_direct_func_call.t",
                        "source/tlang/testing/simple_function_recursion_factorial.t",

                        "source/tlang/testing/simple_conditionals.t",
                        "source/tlang/testing/nested_conditionals.t",
                        "source/tlang/testing/simple_function_decls.t",
                        "source/tlang/testing/simple_variables_only_decs.t",
                        "source/tlang/testing/simple_variables_decls_ass.t",
                        "source/tlang/testing/simple_while.t",
                        
                        "source/tlang/testing/simple_for_loops.t",
                        "source/tlang/testing/simple_cast.t",
                        
                        "source/tlang/testing/simple_pointer.t",
                        "source/tlang/testing/simple_pointer_cast_le.t",

                        "source/tlang/testing/simple_stack_arrays4.t",
                        "source/tlang/testing/simple_stack_array_coerce.t",
                        "source/tlang/testing/simple_stack_array_coerce_ptr_syntax.t",
                        "source/tlang/testing/complex_stack_array_coerce.t",


                        "source/tlang/testing/complex_stack_arrays1.t",
                        "source/tlang/testing/simple_arrays.t",
                        "source/tlang/testing/simple_arrays2.t",
                        "source/tlang/testing/simple_arrays4.t",


                        "source/tlang/testing/simple_pointer_array_syntax.t",
                        ];
    foreach(string testFile; testFiles)
    {
        beginCompilation([testFile]);
    }
}

/**
 * Tests the following pipeline:
 *
 * 1. lexing -> parsing -> typecheck/codegen -> emit (DGen)
 *
 * Kinds of tests:
 * 
 * 1. Negative tests (must fail)
 */
unittest
{
    // TODO: Be specific about the catches maybe
    string[] failingTestFiles = [
                        "source/tlang/testing/simple_function_return_type_check_bad.t"
    ];

    foreach(string testFile; failingTestFiles)
    {
        try
        {
            beginCompilation([testFile]);
            assert(false);
        }
        catch(TError)
        {
            assert(true);
        }
        catch(Exception e)
        {
            assert(false);
        }
    }
}

/**
 * Tests the following pipeline:
 *
 * 1. lexing -> parsing -> typecheck/codegen
 *
 * Kinds of tests:
 * 
 * 1. Positive tests (must pass)
 * 2. Negative tests (must fail)
 */
unittest
{
    // TODO: Enesure we keep this up-to-date with the d.yml
    string[] testFilesGood = [
                        "source/tlang/testing/return/simple_return_expressionless.t",
                        "source/tlang/testing/return/simple_return_type.t",
                        "source/tlang/testing/typecheck/simple_function_call.t",

                        "source/tlang/testing/simple_arrays.t",
                        "source/tlang/testing/simple_arrays2.t",
                        "source/tlang/testing/simple_arrays4.t",

                        "source/tlang/testing/simple_stack_array_coerce.t",
                        "source/tlang/testing/complex_stack_arrays1.t",

                        "source/tlang/testing/complex_stack_array_coerce_permutation_good.t",
                        "source/tlang/testing/simple1_module_positive.t",
                        "source/tlang/testing/simple2_name_recognition.t",

                        "source/tlang/testing/simple_literals.t",
                        "source/tlang/testing/simple_literals3.t",
                        "source/tlang/testing/simple_literals5.t",
                        "source/tlang/testing/simple_literals6.t",
                        "source/tlang/testing/universal_coerce/simple_coerce_literal_good.t",
                        "source/tlang/testing/universal_coerce/simple_coerce_literal_good_stdalo.t",
                        "source/tlang/testing/simple_function_return_type_check_good.t"
    ];

    foreach(string testFileGood; testFilesGood)
    {
        string sourceText = gibFileData(testFileGood);

        try
        {
            File tmpFile;
            tmpFile.open("/tmp/bruh", "wb");
            Compiler compiler = new Compiler(sourceText, tmpFile);

            // Lex
            compiler.doLex();

            // Parse
            compiler.doParse();

            // Dep gen/typecheck/codegen
            compiler.doTypeCheck();

            assert(true);
        }
        // On Error
        catch(TError e)
        {
            assert(false);
        }
        // On Error
        catch(Exception e)
        {
            gprintln("Yo, we should not be getting this but rather ONLY TErrors, this is a bug to be fixed", DebugType.ERROR);
            assert(false);
        }
    }

    // TODO: ENsure we keep this up to date with the d.yml
    string[] testFilesFail = [
                        "source/tlang/testing/typecheck/simple_function_call_1.t",

                        "source/tlang/testing/simple_stack_array_coerce_wrong.t",

                        "source/tlang/testing/complex_stack_array_coerce_bad1.t",
                        "source/tlang/testing/complex_stack_array_coerce_bad2.t",
                        "source/tlang/testing/complex_stack_array_coerce_bad3.t",

                        "source/tlang/testing/collide_container_module1.t",
                        "source/tlang/testing/collide_container_module2.t",
                        "source/tlang/testing/collide_container_non_module.t",
                        "source/tlang/testing/collide_container.t",
                        "source/tlang/testing/collide_member.t",
                        "source/tlang/testing/precedence_collision_test.t",

                        "source/tlang/testing/else_if_without_if.pl",

                        "source/tlang/testing/simple_literals2.t",
                        "source/tlang/testing/simple_literals4.t",
                        "source/tlang/testing/universal_coerce/simple_coerce_literal_bad.t",
                        "source/tlang/testing/universal_coerce/simple_coerce_literal_bad_stdalon.t",
                        "source/tlang/testing/simple_function_return_type_check_bad.t"
    ];

    foreach(string testFileFail; testFilesFail)
    {
        string sourceText = gibFileData(testFileFail);

        try
        {
            File tmpFile;
            tmpFile.open("/tmp/bruh", "wb");
            Compiler compiler = new Compiler(sourceText, tmpFile);

            // Lex
            compiler.doLex();

            // Parse
            compiler.doParse();

            // Dep gen/typecheck/codegen
            compiler.doTypeCheck();

            // All of these checks should be failing
            assert(false);
        }
        // On Error
        catch(TError e)
        {
            assert(true);
        }
        // We should ONLY be getting TErrors
        catch(Exception e)
        {
            gprintln("Got non TError, this is a bug that must be fixed", DebugType.ERROR);
            assert(false);
        }
    }
}