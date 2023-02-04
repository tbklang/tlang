/**
 * Commands
 *
 * All command-line arguments and their impementations
 */

module commandline.commands;

import jcli;
import std.stdio;
import misc.exceptions : TError;
import std.exception : ErrnoException;
import compiler.lexer.core : Lexer;
import compiler.lexer.tokens : Token;
import compiler.parsing.core : Parser;
import compiler.typecheck.core : TypeChecker;
import gogga;
import compiler.core : Compiler, beginCompilation;
import compiler.configuration : ConfigEntry;
import std.conv : to;
import compiler.codegen.mapper.core : SymbolMappingTechnique;

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
    string sourceFile;

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
        @ArgNamed("symbol-mapper|sm", "The symbol mapping technique to use")
        @(ArgConfig.optional)
        SymbolMappingTechnique symbolTechnique = SymbolMappingTechnique.HASHMAPPER;

        @ArgNamed("prettygen|pg", "Generate pretty-printed code")
        @(ArgConfig.optional)
        bool prettyPrintCodeGen = true;
        
        @ArgNamed("output|o", "Filename of generated object file")
        @(ArgConfig.optional)
        string outputFilename = "tlangout.c";

        @ArgNamed("entrypointTest|et", "Whether or not to emit entrypoint testing code")
        @(ArgConfig.optional)
        bool entrypointTestEmit = true; // TODO: Change this later to `false` of course

        @ArgNamed("library-link|ll", "Paths to any object files to ,ink in during the linking phase")
        @(ArgConfig.optional)
        @(ArgConfig.aggregate)
        string[] bruh;
    }

    void EmitBaseInit(Compiler compiler)
    {
        // Set the symbol mapper technique
        compiler.getConfig().addConfig(ConfigEntry("emit:mapper", symbolTechnique));

        // Set whether pretty-printed code should be generated
        compiler.getConfig().addConfig(ConfigEntry("dgen:pretty_code", prettyPrintCodeGen));

        // Set whether or not to enable the entry point testing code
        compiler.getConfig().addConfig(ConfigEntry("dgen:emit_entrypoint_test", entrypointTestEmit));

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
            Compiler compiler = new Compiler(sourceText, outFile);

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
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
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
            Compiler compiler = new Compiler(sourceText, File());

            /* Setup general configuration parameters */
            BaseCommandInit(compiler);

            
            compiler.doLex();
            writeln("=== Tokens ===\n");
            writeln(compiler.getTokens());
        }
        catch(TError t)
        {
            gprintln(t.msg, DebugType.ERROR);
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
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
            Compiler compiler = new Compiler(sourceText, File());

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
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
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
            Compiler compiler = new Compiler(sourceText, File());

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
        }
        catch(ErrnoException e)
        {
            /* TODO: Use gogga error */
            writeln("Could not open source file "~sourceFile);
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