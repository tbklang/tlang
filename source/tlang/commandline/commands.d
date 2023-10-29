/**
 * Commands
 *
 * All command-line arguments and their impementations
 */

module tlang.commandline.commands;

import jcli;
import std.stdio;
import misc.exceptions : TError;
import std.exception : ErrnoException;
import tlang.compiler.lexer.kinds.basic : BasicLexer;
import tlang.compiler.lexer.core;
import tlang.compiler.parsing.core : Parser;
import tlang.compiler.typecheck.core : TypeChecker;
import gogga;
import tlang.compiler.core : Compiler, beginCompilation;
import tlang.compiler.configuration : ConfigEntry;
import std.conv : to;
import tlang.compiler.codegen.mapper.core : SymbolMappingTechnique;
import core.stdc.stdlib : exit;

//TODO: Re-order the definitions below so that they appear with compile first, then lex, parse, ..., help

public enum VerbosityLevel
{
    info,
    warning,
    error,
    debugg
}

// TODO: Add base command as verbosity is something we will always want to control
// TODO: Try get inheritane working as we may be able to set things then

// Stuff that all commands need
mixin template BaseCommand()
{
    @ArgPositional("source file", "The source file to compile")
    string sourceFile; // TODO: Should accept a list in the future maybe

    @ArgNamed("verbose|v", "Verbosity level")
    @(ArgConfig.optional)
    VerbosityLevel debugLevel;

    void BaseCommandInit(Compiler compiler)
    {
        // Set the verbosity level
        compiler.getConfig().addConfig(ConfigEntry("verbosity", debugLevel));
    }
}


/** 
 * Base requirements for Emit+
 */
mixin template EmitBase()
{
    @ArgGroup("Emit", "Options pertaining to the code emitter")
    {
        @ArgNamed("symbol-mapper|sm", "The symbol mapping technique to use for DGen (C emitter)")
        @(ArgConfig.optional)
        SymbolMappingTechnique symbolTechnique = SymbolMappingTechnique.HASHMAPPER;

        @ArgNamed("prettygen|pg", "Generate pretty-printed code")
        @(ArgConfig.optional)
        bool prettyPrintCodeGen = true;

        @ArgNamed("ccompiler|cc", "The system C compiler to use for DGne (C emitter)")
        @(ArgConfig.optional)
        string systemCC = "clang";
        
        @ArgNamed("output|o", "Filename of generated object file")
        @(ArgConfig.optional)
        string outputFilename = "tlangout.c";

        @ArgNamed("entrypointTest|et", "Whether or not to emit entrypoint testing code")
        @(ArgConfig.optional)
        bool entrypointTestEmit = true; // TODO: Change this later to `false` of course

        @ArgNamed("preinlineArguments|pia", "Whether or not to preinline function call arguments in DGen (C emitter)")
        @(ArgConfig.optional)
        bool preinlineArguments = false; // TODO: Change this later to `true` of course

        @ArgNamed("library-link|ll", "Paths to any object files to ,ink in during the linking phase")
        @(ArgConfig.optional)
        @(ArgConfig.aggregate)
        string[] bruh;
    }

    void EmitBaseInit(Compiler compiler)
    {
        // Set the symbol mapper technique
        compiler.getConfig().addConfig(ConfigEntry("dgen:mapper", symbolTechnique));

        // Set whether pretty-printed code should be generated
        compiler.getConfig().addConfig(ConfigEntry("dgen:pretty_code", prettyPrintCodeGen));

        // Set whether or not to enable the entry point testing code
        compiler.getConfig().addConfig(ConfigEntry("dgen:emit_entrypoint_test", entrypointTestEmit));

        // Set whether or not to enable pre-inlining of function call arguments in DGen
        compiler.getConfig().addConfig(ConfigEntry("dgen:preinline_args", preinlineArguments));

        // Set the C compiler to use for DGen
        compiler.getConfig().addConfig(ConfigEntry("dgen:compiler", systemCC));

        // Set the paths to the object files to link in
        compiler.getConfig().addConfig(ConfigEntry("linker:link_files", bruh));
    }
}

/** 
 * Base requirements for TypeChecker+
 */
mixin template TypeCheckerBase()
{

}

/** 
 * Compile the given source file from start to finish
 */
@Command("compile", "Compiles the given file(s)")
struct compileCommand
{
    mixin BaseCommand!();

    

    mixin EmitBase!();


    void onExecute()
    {
        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            File outFile;
            outFile.open(outputFilename, "w");
            Compiler compiler = new Compiler(sourceText, sourceFile, outFile);

            /* Setup general configuration parameters */
            BaseCommandInit(compiler);

            /* Perform tokenization */
            compiler.doLex();
            writeln("=== Tokens ===\n");
            writeln(compiler.getTokens());

            /* Perform parsing */
            compiler.doParse();
            // TODO: Do something with the returned module
            auto modulel = compiler.getModule();

            /* Perform typechecking/codegen */
            compiler.doTypeCheck();

            /**
             * Configure the emitter and then perform code emit
             */
            EmitBaseInit(compiler);
            compiler.doEmit();
        }
        catch(TError t)
        {
            gprintln(t.msg, DebugType.ERROR);
            exit(-1);
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
            exit(-2);
        }
        catch(Exception e)
        {
            gprintln(e.msg, DebugType.ERROR);
            exit(-1);
        }
    }
}

/**
* Only perform tokenization of the given source files
*/
@Command("lex", "Performs tokenization of the given file(s)")
struct lexCommand
{
    mixin BaseCommand!();

    void onExecute()
    {
        writeln("Performing tokenization on file: "~sourceFile);

        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Compiler compiler = new Compiler(sourceText, sourceFile, File());

            /* Setup general configuration parameters */
            BaseCommandInit(compiler);

            
            compiler.doLex();
            writeln("=== Tokens ===\n");
            writeln(compiler.getTokens());
        }
        catch(TError t)
        {
            gprintln(t.msg, DebugType.ERROR);
            exit(-1);
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
            exit(-2);
        }
    }
}

@Command("syntaxcheck", "Check the syntax of the program")
struct parseCommand
{
    mixin BaseCommand!();


    /* TODO: Add missing implementation for this */
    void onExecute()
    {
        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Compiler compiler = new Compiler(sourceText, sourceFile, File());

            /* Setup general configuration parameters */
            BaseCommandInit(compiler);

            compiler.doLex();
            writeln("=== Tokens ===\n");
            writeln(compiler.getTokens());

            /* Perform parsing */
            compiler.doParse();
            // TODO: Do something with the returned module
            auto modulel = compiler.getModule();
        }
        catch(TError t)
        {
            gprintln(t.msg, DebugType.ERROR);
            exit(-1);
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
            exit(-2);
        }
    }
}

@Command("typecheck", "Perform typechecking on the program")
struct typecheckCommand
{
    mixin BaseCommand!();


    void onExecute()
    {
        try
        {
            /* Read the source file's data */
            File file;
            file.open(sourceFile, "r");
            ulong fSize = file.size();
            byte[] data;
            data.length = fSize;
            data = file.rawRead(data);
            string sourceText = cast(string)data;
            file.close();

            /* Begin lexing process */
            Compiler compiler = new Compiler(sourceText, sourceFile, File());

            /* Setup general configuration parameters */
            BaseCommandInit(compiler);

            compiler.doLex();
            writeln("=== Tokens ===\n");
            writeln(compiler.getTokens());

            /* Perform parsing */
            compiler.doParse();
            // TODO: Do something with the returned module
            auto modulel = compiler.getModule();

            /* Perform typechecking/codegen */
            compiler.doTypeCheck();
        }
        catch(TError t)
        {
            gprintln(t.msg, DebugType.ERROR);
            exit(-1);
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
            exit(-2);
        }
    }
}

@Command("help", "Shows the help screen")
struct helpCommand
{
    /* TODO: Add missing implementation for this */
    void onExecute()
    {
        /* TODO: We want to show the commands list, not a seperate help command */
    }
}