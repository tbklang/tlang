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
import compiler.symbols.typing.core : Type, Primitive;

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

    private ulong transformDepth = 0;

    private string genTabs(ulong count)
    {
        string tabStr;
        for(ulong i = 0; i < count; i++)
        {
            tabStr~="\t";
        }
        return tabStr;
    }

    public override string transform(const Instruction instruction)
    {
        writeln("\n");
        gprintln("transform(): "~to!(string)(instruction));
        transformDepth++;

        // At any return decrement the depth
        scope(exit)
        {
            transformDepth--;
        }

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
                // gprintln("Before crash: "~to!(string)(getCurrentInstruction()));
                // nextInstruction();
                // Instruction varAssInstr = getCurrentInstruction();
                
                VariableAssignmentInstr varAssInstr = varDecInstr.getAssignmentInstr();

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

            // TODO: I like having `lhs == rhs` for `==` or comparators but not spaces for `lhs+rhs`

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
        /**
        * If statements (IfStatementInstruction)
        */
        else if(cast(IfStatementInstruction)instruction)
        {
            IfStatementInstruction ifStatementInstruction = cast(IfStatementInstruction)instruction;

            BranchInstruction[] branchInstructions = ifStatementInstruction.getBranchInstructions();
            gprintln("Holla"~to!(string)(branchInstructions));

            string emit;

            for(ulong i = 0; i < branchInstructions.length; i++)
            {
                BranchInstruction curBranchInstr = branchInstructions[i];

                if(curBranchInstr.hasConditionInstr())
                {
                    Value conditionInstr = cast(Value)curBranchInstr.getConditionInstr();

                    string hStr = (i == 0) ? "if" : genTabs(transformDepth)~"else if";

                    emit~=hStr~"("~transform(conditionInstr)~")\n";

                    emit~=genTabs(transformDepth)~"{\n";

                    foreach(Instruction branchBodyInstr; curBranchInstr.getBodyInstructions())
                    {
                        emit~=genTabs(transformDepth)~"\t"~transform(branchBodyInstr)~"\n";
                    }

                    emit~=genTabs(transformDepth)~"}\n";
                }
                else
                {
                    emit~=genTabs(transformDepth)~"else\n";

                    emit~=genTabs(transformDepth)~"{\n";

                    foreach(Instruction branchBodyInstr; curBranchInstr.getBodyInstructions())
                    {
                        emit~=genTabs(transformDepth)~"\t"~transform(branchBodyInstr)~"\n";
                    }

                    emit~=genTabs(transformDepth)~"}\n";
                }
            }

            return emit;
        }
        /**
        * While loops (WhileLoopInstruction)
        *
        * TODO: Add do-while check
        */
        else if(cast(WhileLoopInstruction)instruction)
        {
            WhileLoopInstruction whileLoopInstr = cast(WhileLoopInstruction)instruction;

            BranchInstruction branchInstr = whileLoopInstr.getBranchInstruction();
            Value conditionInstr = branchInstr.getConditionInstr();
            Instruction[] bodyInstructions = branchInstr.getBodyInstructions();

            string emit;

            /* Generate the `while(<expr>)` and opening curly brace */
            emit = "while("~transform(conditionInstr)~")\n";
            emit~=genTabs(transformDepth)~"{\n"; 

            /* Transform each body statement */
            foreach(Instruction curBodyInstr; bodyInstructions)
            {
                emit~=genTabs(transformDepth)~"\t"~transform(curBodyInstr)~"\n";
            }

            /* Closing curly brace */
            emit~=genTabs(transformDepth)~"}";

            return emit;
        }
        /**
        * For loops (ForLoopInstruction)
        */
        else if(cast(ForLoopInstruction)instruction)
        {
            ForLoopInstruction forLoopInstr = cast(ForLoopInstruction)instruction;

            BranchInstruction branchInstruction = forLoopInstr.getBranchInstruction();
            Value conditionInstr = branchInstruction.getConditionInstr();
            Instruction[] bodyInstructions = branchInstruction.getBodyInstructions();

            string emit = "for(";

            // Emit potential pre-run instruction
            emit ~= forLoopInstr.hasPreRunInstruction() ? transform(forLoopInstr.getPreRunInstruction()) : ";";

            // Condition
            emit ~= transform(conditionInstr)~";";

            // NOTE: We are leaving the post-iteration blank due to us including it in the body
            // TODO: We can hoist bodyInstructions[$] maybe if we want to generate it as C-for-loops
            // if(forLoopInstr.hasPostIterationInstruction())
            emit ~= ")\n";

            // Open curly (begin body)
            emit~=genTabs(transformDepth)~"{\n"; 

            /* Transform each body statement */
            foreach(Instruction curBodyInstr; bodyInstructions)
            {
                emit~=genTabs(transformDepth)~"\t"~transform(curBodyInstr)~"\n";
            }

            // Close curly (body end)
            emit~=genTabs(transformDepth)~"}"; 

            return emit;
        }
        /**
        * Unary operators (UnaryOpInstr)
        */
        else if(cast(UnaryOpInstr)instruction)
        {
            UnaryOpInstr unaryOpInstr = cast(UnaryOpInstr)instruction;
            Value operandInstruction = cast(Value)unaryOpInstr.getOperand();
            assert(operandInstruction);

            string emit;
            
            /* The operator's symbol */
            emit ~= getCharacter(unaryOpInstr.getOperator());

            /* Transform the operand */
            emit ~= transform(operandInstruction);

            return emit;
        }
        /**
        * Pointer dereference assignment (PointerDereferenceAssignmentInstruction)
        */
        else if(cast(PointerDereferenceAssignmentInstruction)instruction)
        {
            PointerDereferenceAssignmentInstruction pointerDereferenceAssignmentInstruction = cast(PointerDereferenceAssignmentInstruction)instruction;
            Value lhsPtrAddrExprInstr = pointerDereferenceAssignmentInstruction.getPointerEvalInstr();
            assert(lhsPtrAddrExprInstr);
            Value rhsAssExprInstr = pointerDereferenceAssignmentInstruction.getAssExprInstr();
            assert(rhsAssExprInstr);

            string emit;

            /* Star followed by transformation of the pointer address expression */
            string starsOfLiberty;
            for(ulong i = 0; i < pointerDereferenceAssignmentInstruction.getDerefCount(); i++)
            {
                starsOfLiberty ~= "*";
            }
            emit ~= starsOfLiberty~transform(lhsPtrAddrExprInstr);

            /* Assignment operator follows */
            emit ~= " = ";

            /* Expression to be assigned on the right hand side */
            emit ~= transform(rhsAssExprInstr)~";";


            return emit;
        }
        /**
        * Discard instruction (DiscardInstruction)
        */
        else if(cast(DiscardInstruction)instruction)
        {
            DiscardInstruction discardInstruction = cast(DiscardInstruction)instruction;
            Value valueInstruction = discardInstruction.getExpressionInstruction();

            string emit;

            /* Transform the expression */
            emit ~= transform(valueInstruction)~";";

            return emit;
        }
        /**
        * Type casting instruction (CastedValueInstruction)
        */
        else if(cast(CastedValueInstruction)instruction)
        {
            CastedValueInstruction castedValueInstruction = cast(CastedValueInstruction)instruction;
            Type castingTo = castedValueInstruction.getCastToType();

            // TODO: Dependent on type being casted one must handle different types, well differently (as is case for atleast OOP)

            Value uncastedInstruction = castedValueInstruction.getEmbeddedInstruction();


            string emit;

            /* Handling of primitive types */
            if(cast(Primitive)castingTo)
            {
                /* Add the actual cast */
                emit ~= "("~to!(string)(castingTo)~")";

                /* The expression being casted */
                emit ~= transform(uncastedInstruction);
            }
            else
            {
                // TODO: Implement this
                gprintln("Non-primitive type casting not yet implemented", DebugType.ERROR);
                assert(false);
            }

            


            return emit;
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
        emitFunctionPrototypes();
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
     * Emits the function prototypes
     */
    private void emitFunctionPrototypes()
    {
        gprintln("Function definitions needed: "~to!(string)(getFunctionDefinitionsCount()));

        Instruction[][string] functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues();

        string[] functionNames = getFunctionDefinitionNames();

        gprintln("WOAH: "~to!(string)(functionNames));

        foreach(string currentFunctioName; functionNames)
        {
            emitFunctionPrototype(currentFunctioName);
            file.writeln();
        }
    }

    /** 
     * Emits the function definitions
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

    private void emitFunctionPrototype(string functionName)
    {
        selectQueue(QueueType.FUNCTION_DEF_QUEUE, functionName);

        gprintln("emotFunctionDefinition(): Function: "~functionName~", with "~to!(string)(getSelectedQueueLength())~" many instructions");
    
        //TODO: Look at nested definitions or nah? (Context!!)
        //TODO: And what about methods defined in classes? Those should technically be here too
        Function functionEntity = cast(Function)typeChecker.getResolver().resolveBest(typeChecker.getModule(), functionName); //TODO: Remove `auto`
        
        // Emit the function signature
        file.writeln(generateSignature(functionEntity)~";");
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

        // Test for `simple_functions.t` (function call testing)
        if(cmp(typeChecker.getModule().getName(), "simple_functions") == 0)
        {
            file.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    assert(t_7b6d477c5859059f16bc9da72fc8cc3b == 22);
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);
    
    banana(1);
    assert(t_7b6d477c5859059f16bc9da72fc8cc3b == 72);
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);

    return 0;
}`);
        }
        else if(cmp(typeChecker.getModule().getName(), "simple_while") == 0)
        {
            file.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function(3);
    printf("result: %d\n", result);
    assert(result == 3);

    return 0;
}`);
        }
        else if(cmp(typeChecker.getModule().getName(), "simple_for_loops") == 0)
        {
            file.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function(3);
    printf("result: %d\n", result);
    assert(result == 3);

    return 0;
}`);
        }
        else if(cmp(typeChecker.getModule().getName(), "simple_pointer") == 0)
        {
            file.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    thing();
    assert(t_87bc875d0b65f741b69fb100a0edebc7 == 4);

    return 0;
}`);
        }
        else
        {
            file.writeln(`
int main()
{
    return 0;
}
`);
        }
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