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
            // TODO: Change to a TError
            // throw new Exception("Key not found");
            return false;
        }
    }
}

public class Compiler
{
    /* The input source code */
    private string inputSource;

    /* The lexer */
    private Lexer lexer;

    /* The parser */
    private Parser parser;

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

    public void compile()
    {
        // TODO: Add each step of the pipeline here

        /* Setup the lexer and begin lexing */
        this.lexer = new Lexer(inputSource);
        this.lexer.performLex();
    
        /* Extract the tokens */
        Token[] tokens = lexer.getTokens();
        gprintln("Collected "~to!(string)(tokens));

        /* Spawn a new parser with the provided tokens */
        this.parser = new Parser(tokens);

        /* The parsed Module */
        Module modulle = parser.parse();

        /* Spawn a new typechecker/codegenerator on the module */
        this.typeChecker = new TypeChecker(modulle);

        /* Perform typechecking/codegen */
        this.typeChecker.beginCheck();

        /* Perform code emitting */
        this.emitter = new DCodeEmitter(typeChecker, emitOutFile, config);
        emitter.emit(); // Emit the code
        emitOutFile.close(); // Flush (perform the write() syscall)
        emitter.finalize(); // Call CC on the file containing generated C code
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