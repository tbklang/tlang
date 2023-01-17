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

    private string[string] config;

    /* TODO: Make the default config */
    private void defaultConfig()
    {
        /* Enable Behaviour-C fixes */
        setConfig("behavec:preinline_args", "true");
    }

    public void setConfig(string key, string value)
    {
        config[key] = value;
    }

    public string getConfig(string key)
    {
        import std.algorithm : canFind;
        if(canFind(config.keys(), key))
        {
            return config[key];
        }
        else
        {
            // TODO: Change to a TError
            throw new Exception("Key not found");
        }
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

        /* Enable the default config */
        defaultConfig();
    }

    public void compile()
    {
        // TODO: Add each step of the pipeline here

        /* Setup the lexer and begin lexing */
        this.lexer = new Lexer(inputSource);
        if(lexer.performLex())
        {
            /* Extract the tokens */
            Token[] tokens = lexer.getTokens();
            gprintln("Collected "~to!(string)(tokens));

            /* Spawn a new parser with the provided tokens */
            this.parser = new Parser(tokens);

            /* The parsed Module */
            Module modulle = parser.parse();

            /* Spawn a new typechecker/codegenerator on the module */
            this.typeChecker = new TypeChecker(modulle);

            /* Perform code emitting */
            this.emitter = new DCodeEmitter(typeChecker, emitOutFile);
            emitter.emit(); // Emit the code
            emitOutFile.close(); // Flush (perform the write() syscall)
            emitter.finalize(); // Call CC on the file containing generated C code
        }
        else
        {
            // TODO: Throw a lexing error  here or rather `performLex()` should be doing that
        }
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

    Lexer[] lexers;
    foreach(string sourceFile; sourceFiles)
    {
        gprintln("Reading source file '"~sourceFile~"' ...");
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

        gprintln("Performing tokenization on '"~sourceFile~"' ...");

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        bool status = currentLexer.performLex();
        if(!status)
        {
            return;
        }
        
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));

        gprintln("Parsing tokens...");
        Parser parser = new Parser(currentLexer.getTokens());
        Module modulle;
        
        import misc.exceptions;

        try
        {
            modulle = parser.parse();
        }
        catch(TError e)
        {
            gprintln(e.msg, DebugType.ERROR);
            exit(0); /* TODO: Exit code */  /* TODO: Version that returns or asserts for unit tests */
        }
        
        

        gprintln("Type checking and symbol resolution...");
        try
        {
            TypeChecker typeChecker = new TypeChecker(modulle);
            typeChecker.beginCheck();


            File outFile;
            outFile.open("tlangout.c", "w");
            CodeEmitter emitter = new DCodeEmitter(typeChecker, outFile);

            
            
            emitter.emit();
            outFile.close();

            // Cause the generation to happen
            emitter.finalize();
        }
        // catch(CollidingNameException e)
        // {
        //     gprintln(e.msg, DebugType.ERROR);
        //     //gprintln("Stack trace:\n"~to!(string)(e.info));
        // }
        catch(TypeCheckerException e)
        {
            gprintln(e.msg, DebugType.ERROR);
            exit(0);
        }

        

        // import compiler.codegen.core;
        // CodeGenerator codegen = new DCodeGenerator(modulle);
        // codegen.build();
        
        // typeChecker.check();
    }
}