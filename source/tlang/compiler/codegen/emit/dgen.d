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
import compiler.typecheck.dependency.core : Context, FunctionData, DNode;
import compiler.codegen.mapper : SymbolMapper;
import compiler.symbols.data : SymbolType, Variable, Function, VariableParameter;
import compiler.symbols.check : getCharacter;
import misc.utils : Stack;

public final class DCodeEmitter : CodeEmitter
{    
    // Set to true when processing a variable declaration
    // which expects an assignment. Set to false when
    // said variable assignment has been processed
    private bool varDecWantsConsumeVarAss = false;


    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);
    }

    public override string transform(const Instruction instruction)
    {
        import std.stdio;
        writeln("\n");
        gprintln("transform(): "~to!(string)(instruction));

        /* VariableAssignmentInstr */
        if(cast(VariableAssignmentInstr)instruction)
        {
            gprintln("type: VariableAssignmentInstr");

            VariableAssignmentInstr varAs = cast(VariableAssignmentInstr)instruction;
            Context context = varAs.getContext();

            gprintln("Is ContextNull?: "~to!(string)(context is null));
            gprintln("Wazza contect: "~to!(string)(context.container));
            auto typedEntityVariable = context.tc.getResolver().resolveBest(context.getContainer(), varAs.varName); //TODO: Remove `auto`

            string renamedSymbol = SymbolMapper.symbolLookup(typedEntityVariable);

            
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
            gprintln("type: VariableDeclaration");

            VariableDeclaration varDecInstr = cast(VariableDeclaration)instruction;
            Context context = varDecInstr.getContext();

            Variable typedEntityVariable = cast(Variable)context.tc.getResolver().resolveBest(context.getContainer(), varDecInstr.varName); //TODO: Remove `auto`

            //NOTE: We should remove all dots from generated symbol names as it won't be valid C (I don't want to say C because
            // a custom CodeEmitter should be allowed, so let's call it a general rule)
            //
            //simple_variables.x -> simple_variables_x
            //NOTE: We may need to create a symbol table actually and add to that and use that as these names
            //could get out of hand (too long)
            // NOTE: Best would be identity-mapping Entity's to a name
            string renamedSymbol = SymbolMapper.symbolLookup(typedEntityVariable);


            // Check to see if this declaration has an assignment attached
            if(typedEntityVariable.getAssignment())
            {
                // Set flag to expect different transform generation for VariableAssignment
                varDecWantsConsumeVarAss = true;

                // Fetch the variable assignment instruction
                gprintln("Before crash: "~to!(string)(getCurrentInstruction()));
                nextInstruction();
                Instruction varAssInstr = getCurrentInstruction();
                
                // Generate the code to emit
                return varDecInstr.varType~" "~renamedSymbol~" = "~transform(varAssInstr)~";";
            }



            return varDecInstr.varType~" "~renamedSymbol~";";
        }
        /* LiteralValue */
        else if(cast(LiteralValue)instruction)
        {
            gprintln("type: LiteralValue");

            LiteralValue literalValueInstr = cast(LiteralValue)instruction;

            return to!(string)(literalValueInstr.data);
        }
        /* FetchValueVar */
        else if(cast(FetchValueVar)instruction)
        {
            gprintln("type: FetchValueVar");

            FetchValueVar fetchValueVarInstr = cast(FetchValueVar)instruction;
            Context context = fetchValueVarInstr.getContext();

            Variable typedEntityVariable = cast(Variable)context.tc.getResolver().resolveBest(context.getContainer(), fetchValueVarInstr.varName); //TODO: Remove `auto`

            //TODO: THis is giving me kak (see issue #54), it's generating name but trying to do it for the given container, relative to it
            //TODO: We might need a version of generateName that is like generatenamebest (currently it acts like generatename, within)

            string renamedSymbol = SymbolMapper.symbolLookup(typedEntityVariable);

            return renamedSymbol;
        }
        /* BinOpInstr */
        else if(cast(BinOpInstr)instruction)
        {
            gprintln("type: BinOpInstr");

            BinOpInstr binOpInstr = cast(BinOpInstr)instruction;

            return transform(binOpInstr.lhs)~to!(string)(getCharacter(binOpInstr.operator))~transform(binOpInstr.rhs);
        }
        /* FuncCallInstr */
        else if(cast(FuncCallInstr)instruction)
        {
            gprintln("type: FuncCallInstr");

            FuncCallInstr funcCallInstr = cast(FuncCallInstr)instruction;
            Context context = funcCallInstr.getContext();
            assert(context);

            Function functionToCall = cast(Function)context.tc.getResolver().resolveBest(context.getContainer(), funcCallInstr.functionName); //TODO: Remove `auto`

            // TODO: SymbolLookup?

            string emit = functionToCall.getName()~"(";

            //TODO: Insert argument passimng code here
            //NOTE: Typechecker must have checked for passing arguments to a function that doesn't take any, for example

            //NOTE (Behaviour): We may want to actually have an preinliner for these arguments
            //such to enforce a certain ordering. I believe this should be done in the emitter stage,
            //so it is best placed here
            if(functionToCall.hasParams())
            {
                Value[] argumentInstructions = funcCallInstr.getEvaluationInstructions();
                string argumentString;
                
                for(ulong argIdx = 0; argIdx < argumentInstructions.length; argIdx++)
                {
                    Value currentArgumentInstr = argumentInstructions[argIdx];
                    argumentString~=transform(currentArgumentInstr);

                    if(argIdx != (argumentInstructions.length-1))
                    {
                        argumentString~=", ";
                    }
                }

                emit~=argumentString;
            }

            emit ~= ")";

            return emit;
        }
        /* ReturnInstruction */
        else if(cast(ReturnInstruction)instruction)
        {
            gprintln("type: ReturnInstruction");

            ReturnInstruction returnInstruction = cast(ReturnInstruction)instruction;
            Context context = returnInstruction.getContext();
            assert(context);

            /* Get the return expression instruction */
            Value returnExpressionInstr = returnInstruction.getReturnExpInstr();

            return "return "~transform(returnExpressionInstr)~";";
        }

        return "<TODO: Base emit: "~to!(string)(instruction)~">";
    }


    public override void emit()
    {
        // Emit header comment (NOTE: Change this to a useful piece of text)
        emitHeaderComment("Place any extra information by code generator here"); // NOTE: We can pass a string with extra information to it if we want to

        // Emit static allocation code
        emitStaticAllocations();

        // Emit globals
        emitCodeQueue();

        // Emit function definitions
        emitFunctionDefinitions();

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
        selectQueue(QueueType.ALLOC_QUEUE);
        gprintln("Static allocations needed: "~to!(string)(getQueueLength()));

        file.writeln();
    }

    /** 
     * TOOD: We should have an nextInstruction() esque thing for this
     */
    private void emitFunctionDefinitions()
    {
        gprintln("Function definitions needed: "~to!(string)(getFunctionDefinitionsCount()));

        Instruction[][string] functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues();

        string[] functionNames = getFunctionDefinitionNames();

        gprintln("WOAH: "~to!(string)(functionNames));

        foreach(string currentFunctioName; functionNames)
        {
            emitFunctionDefinition(currentFunctioName);
            file.writeln();
        }   
    }

    private string generateSignature(Function func)
    {
        string signature;

        // <type> <functionName> (
        signature = func.getType()~" "~func.getName()~"(";

        // Generate parameter list
        if(func.hasParams())
        {
            VariableParameter[] parameters = func.getParams();
            string parameterString;
            
            for(ulong parIdx = 0; parIdx < parameters.length; parIdx++)
            {
                Variable currentParameter = parameters[parIdx];

                // Generate the symbol-mapped names for the parameters
                Variable typedEntityVariable = cast(Variable)typeChecker.getResolver().resolveBest(func, currentParameter.getName()); //TODO: Remove `auto`
                string renamedSymbol = SymbolMapper.symbolLookup(typedEntityVariable);


                // Generate <type> <parameter-name (symbol mapped)>
                parameterString~=currentParameter.getType()~" "~renamedSymbol;

                if(parIdx != (parameters.length-1))
                {
                    parameterString~=", ";
                }
            }

            signature~=parameterString;
        }

        // )
        signature~=")";

        return signature;

    }

    private void emitFunctionDefinition(string functionName)
    {
        selectQueue(QueueType.FUNCTION_DEF_QUEUE, functionName);

        gprintln("emotFunctionDefinition(): Function: "~functionName~", with "~to!(string)(getSelectedQueueLength())~" many instructions");
    
        //TODO: Look at nested definitions or nah? (Context!!)
        //TODO: And what about methods defined in classes? Those should technically be here too
        Function functionEntity = cast(Function)typeChecker.getResolver().resolveBest(typeChecker.getModule(), functionName); //TODO: Remove `auto`
        
        // Emit the function signature
        file.writeln(generateSignature(functionEntity));

        // Emit opening curly brace
        file.writeln(getCharacter(SymbolType.OCURLY));

        // Emit body
        while(hasInstructions())
        {
            Instruction curFuncBodyInstr = getCurrentInstruction();

            string emit = transform(curFuncBodyInstr);
            gprintln("emitFunctionDefinition("~functionName~"): Emit: "~emit);
            file.writeln("\t"~emit);
            
            nextInstruction();
        }

        // Emit closing curly brace
        file.writeln(getCharacter(SymbolType.CCURLY));
    }

    private void emitCodeQueue()
    {
        selectQueue(QueueType.GLOBALS_QUEUE);
        gprintln("Code emittings needed: "~to!(string)(getQueueLength()));

        while(hasInstructions())
        {
            Instruction currentInstruction = getCurrentInstruction();
            file.writeln(transform(currentInstruction));

            nextInstruction();
        }

        file.writeln();
    }

    private void emitEntryPoint()
    {
        //TODO: Implement me

        // NOTE: Remove this printf
        file.writeln(`
// NOTE: The below is testing code and should be removed
#include<stdio.h>
int main()
{
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);
    banana(1);
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);
    return 0;
}`);
    }











    public override void finalize()
    {
        try
        {
            //NOTE: Change to system compiler (maybe, we need to choose a good C compiler)
            Pid ccPID = spawnProcess(["clang", "-o", "tlang.out", file.name()]);

            int code = wait(ccPID);

            if(code)
            {
                //NOTE: Make this a TLang exception
                throw new Exception("The CC exited with a non-zero exit code ("~to!(string)(code)~")");
            }
        }
        catch(ProcessException e)
        {
            gprintln("NOTE: Case where it exited and Pid now inavlid (if it happens it would throw processexception surely)?", DebugType.ERROR);
            assert(false);
        }
    }
}