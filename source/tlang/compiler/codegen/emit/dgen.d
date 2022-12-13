module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;
import gogga;
import std.range : walkLength;
import std.string : wrap;
import std.process : spawnProcess, Pid, ProcessException, wait;
import compiler.typecheck.dependency.core : Context;
import compiler.codegen.mapper : SymbolMapper;
import compiler.symbols.data : SymbolType, Variable;
import compiler.symbols.check : getCharacter;
import misc.utils : Stack;

public final class DCodeEmitter : CodeEmitter
{
    private Stack!(Instruction) varAssStack;
    

    // Set to true when processing a variable declaration
    // which expects an assignment. Set to false when
    // said variable assignment has been processed
    private bool varDecWantsConsumeVarAss = false;


    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);

        varAssStack = new Stack!(Instruction)();
    }

    public override string transform(const Instruction instruction)
    {
        /* VariableAssignmentInstr */
        if(cast(VariableAssignmentInstr)instruction)
        {
            VariableAssignmentInstr varAs = cast(VariableAssignmentInstr)instruction;
            Context context = varAs.getContext();

            gprintln("Is ContextNull?: "~to!(string)(context is null));
            auto typedEntityVariable = context.tc.getResolver().resolveBest(context.getContainer(), varAs.varName); //TODO: Remove `auto`
            string typedEntityVariableName = context.tc.getResolver().generateName(context.getContainer(), typedEntityVariable);

            string renamedSymbol = SymbolMapper.symbolLookup(context.getContainer(), typedEntityVariableName);

            
            // If we are needed as part of a VariabvleDeclaration-with-assignment
            if(varDecWantsConsumeVarAss)
            {
                // Generate the code to emit (only the RHS of the = sign)
                string emitCode = transform(varAs.data);

                // Reset flag
                varDecWantsConsumeVarAss = false;

                return emitCode;
            }


            return renamedSymbol~" = "~transform(varAs.data)~";";
        }
        /* VariableDeclaration */
        else if(cast(VariableDeclaration)instruction)
        {
            VariableDeclaration varDecInstr = cast(VariableDeclaration)instruction;
            Context context = varDecInstr.getContext();

            Variable typedEntityVariable = cast(Variable)context.tc.getResolver().resolveBest(context.getContainer(), varDecInstr.varName); //TODO: Remove `auto`
            string typedEntityVariableName = context.tc.getResolver().generateName(context.getContainer(), typedEntityVariable);

            //NOTE: We should remove all dots from generated symbol names as it won't be valid C (I don't want to say C because
            // a custom CodeEmitter should be allowed, so let's call it a general rule)
            //
            //simple_variables.x -> simple_variables_x
            //NOTE: We may need to create a symbol table actually and add to that and use that as these names
            //could get out of hand (too long)
            // NOTE: Best would be identity-mapping Entity's to a name
            string renamedSymbol = SymbolMapper.symbolLookup(context.getContainer(), varDecInstr.varName);


            // Check to see if this declaration has an assignment attached
            if(typedEntityVariable.getAssignment())
            {
                // Set flag to expect different transform generation for VariableAssignment
                varDecWantsConsumeVarAss = true;

                // Fetch the variable assignment instruction
                nextCodeInstruction();
                Instruction varAssInstr = getCurrentCodeInstruction();
                
                // Generate the code to emit
                return varDecInstr.varType~" "~renamedSymbol~" = "~transform(varAssInstr)~";";
            }



            return varDecInstr.varType~" "~renamedSymbol~";";
        }
        /* LiteralValue */
        else if(cast(LiteralValue)instruction)
        {
            LiteralValue literalValueInstr = cast(LiteralValue)instruction;

            return to!(string)(literalValueInstr.data);
        }
        /* FetchValueVar */
        else if(cast(FetchValueVar)instruction)
        {

        }
        /* BinOpInstr */
        else if(cast(BinOpInstr)instruction)
        {
            BinOpInstr binOpInstr = cast(BinOpInstr)instruction;

            return transform(binOpInstr.lhs)~to!(string)(getCharacter(binOpInstr.operator))~transform(binOpInstr.rhs);
        }

        return "<TODO: Base emit: "~to!(string)(instruction)~">";
    }


    public override void emit()
    {
        // Emit header comment (NOTE: Change this to a useful piece of text)
        emitHeaderComment("Place any extra information by code generator here"); // NOTE: We can pass a string with extra information to it if we want to

        gprintln("Static allocations needed: "~to!(string)(getInitQueueLen()));
        emitStaticAllocations();

        gprintln("Code emittings needed: "~to!(string)(getCodeQueueLen()));
        emitCodeQueue();

        //TODO: Emit function definitions

        //TODO: Emit main (entry point)
        emitEntryPoint();
    }

    /** 
     * Emits the header comment which contains information about the source
     * file and the generated code file
     *
     * Params:
     *   headerPhrase = Optional additional string information to add to the header comment
     */
    private void emitHeaderComment(string headerPhrase = "")
    {
        // NOTE: We could maybe fetch input fiel info too? Although it would have to be named similiarly in any case
        // so perhaps just appending a `.t` to the module name below would be fine
        string moduleName = typeChecker.getResolver().generateName(typeChecker.getModule(), typeChecker.getModule()); //TODO: Lookup actual module name (I was lazy)
        string outputCFilename = file.name();

        file.write(`/**
 * TLP compiler generated code
 *
 * Module name: `);
        file.writeln(moduleName);
        file.write(" * Output C file: ");
        file.writeln(outputCFilename);

        if(headerPhrase.length)
        {
            file.write(wrap(headerPhrase, 40, " *\n * ", " * "));
        }
        
        file.write(" */\n");
    }

    /** 
     * Emits the static allocations provided
     *
     * Params:
     *   initQueue = The allocation queue to emit static allocations from
     */
    private void emitStaticAllocations()
    {

    }

    private void emitCodeQueue()
    {
        while(hasCodeInstructions())
        {
            Instruction currentInstruction = getCurrentCodeInstruction();
            file.writeln(transform(currentInstruction));

            nextCodeInstruction();
        }
    }

    private void emitEntryPoint()
    {
        //TODO: Implement me

        file.writeln(`
int main()
{
    return 0;
}`);
    }











    public override void finalize()
    {
        try
        {
            //NOTE: Change to system compiler (maybe, we need to choose a good C compiler)
            Pid ccPID = spawnProcess(["clang", "-o", "tlang.out", file.name()]);

            //NOTE: Case where it exited and Pid now inavlid (if it happens it would throw processexception surely)?
            int code = wait(ccPID);
            gprintln(code);

            if(code)
            {
                //NOTE: Make this a TLang exception
                throw new Exception("The CC exited with a non-zero exit code");
            }
        }
        catch(ProcessException e)
        {
            gprintln("NOTE: Case where it exited and Pid now inavlid (if it happens it would throw processexception surely)?", DebugType.ERROR);
            assert(false);

        }
    }
}