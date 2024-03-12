module tlang.compiler.codegen.emit.dgen;

import tlang.compiler.codegen.emit.core : CodeEmitter;
import tlang.compiler.typecheck.core;
import std.container.slist : SList;
import tlang.compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;
import gogga;
import std.range : walkLength;
import std.string : wrap;
import std.process : spawnProcess, Pid, ProcessException, wait;
import tlang.compiler.typecheck.dependency.core : Context, FunctionData, DNode;
import tlang.compiler.codegen.mapper.core : SymbolMapper;
import tlang.compiler.symbols.data : SymbolType, Variable, Function, VariableParameter;
import tlang.compiler.symbols.check : getCharacter;
import misc.utils : Stack;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.configuration : CompilerConfiguration;
import tlang.compiler.symbols.containers : Module;
import std.format : format;

public final class DCodeEmitter : CodeEmitter
{
    /** 
     * Whether or not symbol mappi g should
     * apply to identifiers
     */
    private bool symbolMapping;

    // NOTE: In future store the mapper in the config please
    this(TypeChecker typeChecker, File file, CompilerConfiguration config, SymbolMapper mapper)
    {
        super(typeChecker, file, config, mapper);

        // By default symbols will be mapped
        enableSymbolMapping();
    }

    /** 
     * Enables symbol mapping
     */
    private void enableSymbolMapping()
    {
     	this.symbolMapping = true;
    }

    /** 
     * Disables symbol mapping
     */
    private void disableSymbolMapping()
    {
     	this.symbolMapping = false;
    }

    private ulong transformDepth = 0;

    private string genTabs(ulong count)
    {
        string tabStr;

        /* Only generate tabs if enabled in compiler config */
        if(config.getConfig("dgen:pretty_code").getBoolean())
        {
            for(ulong i = 0; i < count; i++)
            {
                tabStr~="\t";
            }
        }
        
        return tabStr;
    }

    /** 
     * Given an instance of a Type this will transform it to a string
     *
     * Params:
     *   typeIn = The Type to transform
     *
     * Returns:  The string representation of the transformed type
     */
    public string typeTransform(Type typeIn)
    {
        string stringRepr;

        // TODO: Some types will ident transform

        /* Pointer types */
        if(cast(Pointer)typeIn)
        {
            /* Extract type being pointed to */
            Pointer pointerType = cast(Pointer)typeIn;       
            Type referType = pointerType.getReferredType();

            /* The type is then `transform(<refertype>)*` */
            return typeTransform(referType)~"*";
        }
        /* Integral types transformation */
        else if(cast(Integer)typeIn)
        {
            Integer integralType = cast(Integer)typeIn;

            /* u<>_t or <>_t (Determine signedness) */
            string typeString = integralType.isSigned() ? "int" : "uint";

            /* Width of integer */
            typeString ~= to!(string)(integralType.getSize()*8);

            /* Trailing `_t` */
            typeString ~= "_t";

            return typeString;
        }
        /* Void type */
        else if(cast(Void)typeIn)
        {
            return "void";
        }
        /* Stack-based array type */
        else if(cast(StackArray)typeIn)
        {
            // TODO: Still implement stakc-based arrays
            // we won't be able to tyoe transform just here
            // ... as we need <componentType> <varName>[<arraySize>]
            // ... hence this must be performed in avriable declaration
            StackArray stackArray = cast(StackArray)typeIn;
            
            return typeTransform(stackArray.getComponentType());
            // return "KAK TODO";
        }

        gprintln("Type transform unimplemented for type '"~to!(string)(typeIn)~"'", DebugType.ERROR);
        assert(false);
        // return stringRepr;
    }


    public override string transform(const Instruction instruction)
    {
        writeln("\n");
        gprintln("transform(): "~to!(string)(instruction));
        transformDepth++;

        // The data to emit
        string emmmmit;

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
            auto typedEntityVariable = typeChecker.getResolver().resolveBest(context.getContainer(), varAs.varName); //TODO: Remove `auto`
            gprintln("Hi"~to!(string)(varAs));
            gprintln("Hi"~to!(string)(varAs.data));
            gprintln("Hi"~to!(string)(varAs.data.getInstrType()));

            // NOTE: For tetsing issue #94 coercion (remove when done)
            string typeName = (cast(Type)varAs.data.getInstrType()).getName();
            gprintln("VariableAssignmentInstr: The data to assign's type is: "~typeName);


            /* If it is not external */
            if(!typedEntityVariable.isExternal())
            {
                string renamedSymbol = mapper.symbolLookup(typedEntityVariable);

                emmmmit = renamedSymbol~" = "~transform(varAs.data)~";";
            }
            /* If it is external */
            else
            {
                emmmmit = typedEntityVariable.getName()~" = "~transform(varAs.data)~";";
            }
        }
        /* VariableDeclaration */
        else if(cast(VariableDeclaration)instruction)
        {
            gprintln("type: VariableDeclaration");

            VariableDeclaration varDecInstr = cast(VariableDeclaration)instruction;
            Context context = varDecInstr.getContext();

            Variable typedEntityVariable = cast(Variable)typeChecker.getResolver().resolveBest(context.getContainer(), varDecInstr.varName); //TODO: Remove `auto`

            /* If the variable is not external */
            if(!typedEntityVariable.isExternal())
            {
                //NOTE: We should remove all dots from generated symbol names as it won't be valid C (I don't want to say C because
                // a custom CodeEmitter should be allowed, so let's call it a general rule)
                //
                //simple_variables.x -> simple_variables_x
                //NOTE: We may need to create a symbol table actually and add to that and use that as these names
                //could get out of hand (too long)
                // NOTE: Best would be identity-mapping Entity's to a name
                string renamedSymbol = mapper.symbolLookup(typedEntityVariable);


                // Check if the type is a stack-based array
                // ... if so then take make symbolName := `<symbolName>[<stackArraySize>]`
                if(cast(StackArray)varDecInstr.varType)
                {
                    StackArray stackArray = cast(StackArray)varDecInstr.varType;
                    renamedSymbol~="["~to!(string)(stackArray.getAllocatedSize())~"]";
                }

                // Check to see if this declaration has an assignment attached
                if(typedEntityVariable.getAssignment())
                {
                    Value varAssInstr = varDecInstr.getAssignmentInstr();
                    gprintln("VarDec(with assignment): My assignment type is: "~varAssInstr.getInstrType().getName());

                    // Generate the code to emit
                    emmmmit = typeTransform(cast(Type)varDecInstr.varType)~" "~renamedSymbol~" = "~transform(varAssInstr)~";";
                }
                else
                {
                    emmmmit = typeTransform(cast(Type)varDecInstr.varType)~" "~renamedSymbol~";";
                }
            }
            /* If the variable is external */
            else
            {
                emmmmit = "extern "~typeTransform(cast(Type)varDecInstr.varType)~" "~typedEntityVariable.getName()~";";
            }
        }
        /* LiteralValue */
        else if(cast(LiteralValue)instruction)
        {
            gprintln("type: LiteralValue");

            LiteralValue literalValueInstr = cast(LiteralValue)instruction;

            emmmmit = to!(string)(literalValueInstr.getLiteralValue());
        }
        /* FetchValueVar */
        else if(cast(FetchValueVar)instruction)
        {
            gprintln("type: FetchValueVar");

            FetchValueVar fetchValueVarInstr = cast(FetchValueVar)instruction;
            Context context = fetchValueVarInstr.getContext();

            Variable typedEntityVariable = cast(Variable)typeChecker.getResolver().resolveBest(context.getContainer(), fetchValueVarInstr.varName); //TODO: Remove `auto`

            /* If it is not external */
            if(!typedEntityVariable.isExternal())
            {
                //TODO: THis is giving me kak (see issue #54), it's generating name but trying to do it for the given container, relative to it
                //TODO: We might need a version of generateName that is like generatenamebest (currently it acts like generatename, within)

                string renamedSymbol = mapper.symbolLookup(typedEntityVariable);

                emmmmit = renamedSymbol;
            }
            /* If it is external */
            else
            {
                emmmmit = typedEntityVariable.getName();
            }
        }
        /* BinOpInstr */
        else if(cast(BinOpInstr)instruction)
        {
            gprintln("type: BinOpInstr");

            BinOpInstr binOpInstr = cast(BinOpInstr)instruction;

            // TODO: I like having `lhs == rhs` for `==` or comparators but not spaces for `lhs+rhs`

            /**
             * C compiler's do this thing where:
             *
             * If `<a>` is a pointer and `<b>` is an integer then the
             * following pointer arithmetic is allowed:
             *
             * int* a = (int*)2;
             * a = a + b;
             *
             * But it's WRONG if you do
             *
             * a = a + (int*)b;
             *
             * Even though it makes logical sense coercion wise.
             *
             * Therefore we need to check such a case and yank
             * the cast out me thinks.
             * 
             * See issue #140 (https://deavmi.assigned.network/git/tlang/tlang/issues/140#issuecomment-1892)
             */
            Type leftHandOpType = (cast(Value)binOpInstr.lhs).getInstrType();
            Type rightHandOpType = (cast(Value)binOpInstr.rhs).getInstrType();

            if(typeChecker.isPointerType(leftHandOpType))
            {
                // Sanity check the other side should have been coerced to CastedValueInstruction
                CastedValueInstruction cvInstr = cast(CastedValueInstruction)binOpInstr.rhs;
                assert(cvInstr);

                gprintln("CastedValueInstruction relax setting: Da funk RIGHT ");

                // Relax the CV-instr to prevent it from emitting explicit cast code
                cvInstr.setRelax(true);
            }
            else if(typeChecker.isPointerType(rightHandOpType))
            {
                // Sanity check the other side should have been coerced to CastedValueInstruction
                CastedValueInstruction cvInstr = cast(CastedValueInstruction)binOpInstr.lhs;
                assert(cvInstr);

                gprintln("CastedValueInstruction relax setting: Da funk LEFT ");

                // Relax the CV-instr to prevent it from emitting explicit cast code
                cvInstr.setRelax(true);
            }

            emmmmit = transform(binOpInstr.lhs)~to!(string)(getCharacter(binOpInstr.operator))~transform(binOpInstr.rhs);
        }
        /* FuncCallInstr */
        else if(cast(FuncCallInstr)instruction)
        {
            gprintln("type: FuncCallInstr");

            FuncCallInstr funcCallInstr = cast(FuncCallInstr)instruction;
            Context context = funcCallInstr.getContext();
            assert(context);

            Function functionToCall = cast(Function)typeChecker.getResolver().resolveBest(context.getContainer(), funcCallInstr.functionName); //TODO: Remove `auto`

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

            // If this is a statement-level function call then tack on a `;`
            if(funcCallInstr.isStatementLevel())
            {
                emit ~= ";";
            }

            emmmmit = emit;
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

            emmmmit = "return "~transform(returnExpressionInstr)~";";
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

            emmmmit = emit;
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

            emmmmit = emit;
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

            emmmmit = emit;
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

            emmmmit = emit;
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
            emit ~= starsOfLiberty~"("~transform(lhsPtrAddrExprInstr)~")";

            /* Assignment operator follows */
            emit ~= " = ";

            /* Expression to be assigned on the right hand side */
            emit ~= transform(rhsAssExprInstr)~";";


            emmmmit = emit;
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

            emmmmit = emit;
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


            /**
             * Issue #140
             *
             * If relaxed then just emit the uncasted instruction
             */
            if(castedValueInstruction.isRelaxed())
            {
                /* The original expression */
                emit ~= transform(uncastedInstruction);
            }
            else
            {
                /* Handling of primitive types */
                if(cast(Primitive)castingTo)
                {
                    /* Add the actual cast */
                    emit ~= "("~typeTransform(castingTo)~")";

                    /* The expression being casted */
                    emit ~= transform(uncastedInstruction);
                }
                else
                {
                    // TODO: Implement this
                    gprintln("Non-primitive type casting not yet implemented", DebugType.ERROR);
                    assert(false);
                }
            }

            emmmmit = emit;
        }
        /** 
         * Array indexing (pointer-based arrays)
         *
         * Handles `myArray[<index>]` where `myArray` is
         * of type `int[]` (i.e. `int*`)
         */
        else if(cast(ArrayIndexInstruction)instruction)
        {
            ArrayIndexInstruction arrAssInstr = cast(ArrayIndexInstruction)instruction;

            gprintln("TODO: Implement Pointer-array index emit", DebugType.ERROR);

            gprintln("ArrayInstr: "~arrAssInstr.getIndexedToInstr().toString());
            gprintln("ArrayIndexInstr: "~to!(string)(arrAssInstr.getIndexInstr()));

            
            /* Obtain the entity being indexed */
            Value indexed = arrAssInstr.getIndexedToInstr();

            /* Obtain the index */
            Value index = arrAssInstr.getIndexInstr();

            
            /** 
             * Emit *(<indexedEval>+<index>)
             */
            string emit;
            emit ~= "*(";

            
            emit ~= transform(indexed);
            emit ~= "+";
            emit ~= transform(index);
            emit ~= ")";



            // return "*("~transform(indexed)~"+"~transform(index)~")";
            emmmmit = emit;
        }
        /** 
         * Array assignments (pointer-based arrays)
         *
         * Handles `myArray[<index>] = <expression>` where `myArray`
         * is of type `int[]` (i.e. `int*`)
         */
        else if(cast(ArrayIndexAssignmentInstruction)instruction)
        {
            ArrayIndexAssignmentInstruction arrayAssignmentInstr = cast(ArrayIndexAssignmentInstruction)instruction;

            /** 
             * Obtain the array pointer evaluation
             */
            ArrayIndexInstruction arrayPtrEval = arrayAssignmentInstr.getArrayPtrEval();

            // NOTE: See above
            // /** 
            //  * Obtain the index being assigned at
            //  */
            // Value index = arrayAssignmentInstr.getIndexInstr();

            /** 
             * Obtain the expression being assigned
             */
            Value assignmentInstr = arrayAssignmentInstr.getAssignmentInstr();


            /** 
             * Emit *(<arrayPtrVal>+<indexInstr>) = <assignmentInstr>;
             */
            string emit;
            // NOTE: Below is done by ArrayIndexInstruction
            // emit ~= "*(";
            // emit ~= transform(arrayPtrEval);
            // emit ~= "+";
            // emit ~= transform(index);
            // emit ~= ")";
            emit ~= transform(arrayPtrEval);

            emit ~= " = ";
            emit ~= transform(assignmentInstr);
            emit ~= ";";


            emmmmit = emit; 
        }
        /** 
         * Array indexing (stack-based arrays)
         *
         * Handles `myArray[<index>]` where `myArray` is
         * of type `int[<size>]` (i.e. a stack-array)
         */
        else if(cast(StackArrayIndexInstruction)instruction)
        {
            StackArrayIndexInstruction stackArrInstr = cast(StackArrayIndexInstruction)instruction;
            Context context = stackArrInstr.getContext();
            
            /* Obtain the stack array variable being indexed */
            // TODO: Investigate, nroamlly we do a `FetchValueVar` as like the instr which is fine actually
            FetchValueVar array = cast(FetchValueVar)stackArrInstr.getIndexedToInstr();
            assert(array);
            Variable arrayVariable = cast(Variable)typeChecker.getResolver().resolveBest(context.getContainer(), array.varName);

            /* Perform symbol mapping */
            string arrayName = mapper.symbolLookup(arrayVariable);

            /* Obtain the index expression */
            Value indexInstr = stackArrInstr.getIndexInstr();

            /** 
             * Emit <arrayName>[<index>]
             */
            string emit = arrayName;
            emit ~= "[";
            emit ~= transform(indexInstr);
            emit ~= "]";


            gprintln("TODO: Implement Stack-array index emit", DebugType.ERROR);

            
            

            // return "(TODO: Stack-array index emit)";
            emmmmit = emit;
        }
        /** 
         * Array assignments (stack-based arrays)
         *
         * Handles `myArray[<index>] = <expression>` where `myArray`
         * is of type `int[<size>]` (i.e. a stack-array)
         */
        else if(cast(StackArrayIndexAssignmentInstruction)instruction)
        {
            StackArrayIndexAssignmentInstruction stackArrAssInstr = cast(StackArrayIndexAssignmentInstruction)instruction;
            Context context = stackArrAssInstr.getContext();
            assert(context);

            /** 
             * Obtain the stack array being assigned to
             */
            string arrayName = stackArrAssInstr.getArrayName();
            Variable arrayVariable = cast(Variable)typeChecker.getResolver().resolveBest(context.getContainer(), arrayName);

            /* Perform symbol mapping */
            string arrayNameMapped = mapper.symbolLookup(arrayVariable);

            /* Obtain the index expression */
            Value indexInstr = stackArrAssInstr.getIndexInstr();

            /* Obtain the expresison being assigned */
            Value assignmentInstr = stackArrAssInstr.getAssignedValue();

            /** 
             * Emit <arrayName>[<index>] = <expression>;
             */
            string emit = arrayNameMapped;
            emit ~= "[";
            emit ~= transform(indexInstr);
            emit ~= "]";

            emit ~= " = ";
            emit ~= transform(assignmentInstr);
            emit ~= ";";


            // return "(StackArrAssignmentInstr: TODO)";

            emmmmit = emit;
        }
        // TODO: MAAAAN we don't even have this yet
        // else if(cast(StringExpression))
        /** 
         * Unsupported instruction
         *
         * If you get here then normally it's because
         * you didn't implement a transformation for
         * an instruction yet.
         */
        else
        {
            emmmmit = "<TODO: Base emit: "~to!(string)(instruction)~">";
        }

        return emmmmit;
    }


    public override void emit()
    {
        // TODO: We must figure out how we decide to generate
        // multiple emits here for the many modules within the
        // `Program`
        import tlang.compiler.symbols.data : Program;
        import tlang.compiler.symbols.containers : Module;
        Program program = this.typeChecker.getProgram();
        Module[] programsModules = program.getModules();
        gprintln("emit() has found modules '"~to!(string)(programsModules)~"'", DebugType.INFO);

        foreach(Module curMod; programsModules)
        {
            gprintln("Begin emit process for module '"~to!(string)(curMod)~"'...");

            File modOut;
            modOut.open(format("%s.c", curMod.getName()), "w");

            // Emit header comment (NOTE: Change this to a useful piece of text)
            emitHeaderComment(modOut, curMod, "Place any extra information by code generator here"); // NOTE: We can pass a string with extra information to it if we want to

            // Emit make-available's (externs)
            emitExterns(modOut, curMod);

            // Emit standard integer header import
            emitStdint(modOut, curMod);

            // Emit static allocation code
            emitStaticAllocations(modOut, curMod);

            // Emit globals
            emitCodeQueue(modOut, curMod);

            // Emit function definitions
            emitFunctionPrototypes(modOut, curMod);
            emitFunctionDefinitions(modOut, curMod);

            // Close (and flush anything not yet written)
            modOut.close();
            gprintln("Emit for '"~to!(string)(curMod)~"'");
        }
        
        // If enabled (default: yes) then emit entry point (TODO: change later)
        Module mainModule;
        Function mainFunction;
        if(findEntrypoint(mainModule, mainFunction))
        {
            // FIXME: Disable (needed "a", because "w" overwrote previous writes)
            File entryModOut;
            entryModOut.open(format("%s.c", mainModule.getName()), "a");

            // Emit entry point
            emitEntrypoint(entryModOut, mainModule);

            entryModOut.close();
        }
        else
        {
            // If enabled (default: yes) then emit a testing
            // entrypoint (if one if available for the given
            // test case)
            //
            // In such test cases we assume that the first module
            // is the one we care about
            if(config.getConfig("dgen:emit_entrypoint_test").getBoolean())
            {
                gprintln("Generating a testcase entrypoint for this program", DebugType.WARNING);

                Module firstMod = programsModules[0];
                File firstModOut;
                firstModOut.open(format("%s.c", firstMod.getName()), "a");
                
                // Emit testing entrypoint
                emitTestingEntrypoint(firstModOut, firstMod);

                firstModOut.close();
            }
            else
            {
                gprintln("Could not find an entry point module and function. Missing a main() maybe?", DebugType.ERROR);
            }
        }   
    }

    /** 
     * Attempts to find an entry point within the `Program`,
     * when it is found the ref parameters are filled in
     * and `true` is returned, else they are left untouched
     * and `false` is returned
     *
     * Params:
     *   mainModule = the found main `Module` (if any)
     *   mainFunc = the found main `Function` (if any)
     * Returns: `true` if an entrypoint is found, else
     * `false`
     */
    private bool findEntrypoint(ref Module mainModule, ref Function mainFunc)
    {
        import tlang.compiler.symbols.data : Program, Entity;
        import tlang.compiler.typecheck.resolution : Resolver;
        Program program = this.typeChecker.getProgram();
        Resolver resolver = this.typeChecker.getResolver();
        foreach(Module curMod; program.getModules())
        {
            Entity potentialMain = resolver.resolveWithin(curMod, "main");

            if(potentialMain !is null)
            {
                Function potentialMainFunc = cast(Function)potentialMain;
                if(potentialMainFunc !is null)
                {
                    // TODO: Ensure that it is void or int? (Our decision)
                    // TODO: Ensure arguments (choose what we allow)
                    mainModule = curMod;
                    mainFunc = potentialMainFunc;
                    return true;
                }
            }
        }

        return false;
    }

    /** 
     * Emits the header comment which contains information about the source
     * file and the generated code file
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     *   headerPhrase = Optional additional string information to add to the header comment
     */
    private void emitHeaderComment(File modFile, Module mod, string headerPhrase = "")
    {
        // NOTE: We could maybe fetch input fiel info too? Although it would have to be named similiarly in any case
        // so perhaps just appending a `.t` to the module name below would be fine
        string moduleName = typeChecker.getResolver().generateName(mod, mod); //TODO: Lookup actual module name (I was lazy)
        string outputCFilename = modFile.name();

        modFile.write(`/**
 * TLP compiler generated code
 *
 * Module name: `);
        modFile.writeln(moduleName);
        modFile.write(" * Output C file: ");
        modFile.writeln(outputCFilename);

        if(headerPhrase.length)
        {
            modFile.write(wrap(headerPhrase, 40, " *\n * ", " * "));
        }
        
        modFile.write(" */\n");
    }

    /** 
     * Generates a bunch of extern statements
     * for symbols such as variables and
     * function which are to be exposed
     * in the generated object file such
     * that they can be linked externally
     * to other object files.
     *
     * The method for this is to resolve
     * all `Entity`(s) which are either
     * a `Function` or `Variable` which
     * have an access modifier of `public`
     * and lastly which are only at the
     * module-level in terms of declaration
     *
     * Params:
     *   modOut = the `File` to write the
     * emitted source code to
     *   mod = the current `Module` being
     * processed
     */
    private void emitExterns(File modOut, Module mod)
    {
        gprintln(format("Generating extern statements for module '%s'", mod.getName()));

        Function[] allPubFunc;
        Variable[] allPubVar;

        import tlang.compiler.typecheck.resolution : Resolver;

        Resolver resolver = this.typeChecker.getResolver();

        auto funcAccPred = derive_functionAccMod(AccessorType.PUBLIC);
        auto varAccPred = derive_variableAccMod(AccessorType.PUBLIC);

        bool allPubFuncsAndVars(Entity entity)
        {
            return funcAccPred(entity) || varAccPred(entity);
        }

        Entity[] entities = resolver.resolveWithin(mod, &allPubFuncsAndVars);



        string externGroupBody;
        foreach(Entity entity; entities)
        {
            gprintln(format("Generating extern for '%s'...", entity));

            if(cast(Variable)entity)
            {
                Variable variable = cast(Variable)entity;
            }
            else if(cast(Function)entity)
            {
                Function func = cast(Function)entity;
            }
            else
            {
                gprintln("EXTERN EMIT: Not possible for a non function or variable, CHECK PREDICATE!");
                assert(false);
            }
        }



        import std.string : format;
        modOut.writeln
        (
            format
            (
                "// Extern emits\n%s",
                externGroupBody
            )
        );
    }

    /** 
     * Emits the static allocations provided
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     */
    private void emitStaticAllocations(File modOut, Module mod)
    {
        // Select the static initializations code queue for
        // the given module
        selectQueue(mod, QueueType.ALLOC_QUEUE);
        gprintln("Static allocations needed: "~to!(string)(getQueueLength()));

        modOut.writeln();
    }

    /** 
     * Emits the function prototypes
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     */
    private void emitFunctionPrototypes(File modOut, Module mod)
    {
        gprintln("Function definitions needed: "~to!(string)(getFunctionDefinitionsCount(mod)));

        // Get complete map (should we bypass anything in CodeEmitter for this? Guess it is fair?)
        Instruction[][string] functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues(mod);
        string[] functionNames = getFunctionDefinitionNames(mod);

        gprintln("WOAH: "~to!(string)(functionNames));

        foreach(string currentFunctioName; functionNames)
        {
            emitFunctionPrototype(modOut, mod, currentFunctioName);
            modOut.writeln();
        }
    }

    /** 
     * Emits the function definitions
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     */
    private void emitFunctionDefinitions(File modOut, Module mod)
    {
        gprintln("Function definitions needed: "~to!(string)(getFunctionDefinitionsCount(mod)));

        // Get the function definitions of the current module
        Instruction[][string] functionBodyInstrs = typeChecker.getFunctionBodyCodeQueues(mod);

        string[] functionNames = getFunctionDefinitionNames(mod);

        gprintln("WOAH: "~to!(string)(functionNames));

        foreach(string currentFunctioName; functionNames)
        {
            emitFunctionDefinition(modOut, mod, currentFunctioName);
            modOut.writeln();
        }
    }

    private string generateSignature(Function func)
    {
        string signature;

        // Extract the Function's return Type
        Type returnType = typeChecker.getType(func.context.container, func.getType());

        // <type> <functionName> (
        signature = typeTransform(returnType)~" "~func.getName()~"(";

        // Generate parameter list
        if(func.hasParams())
        {
            VariableParameter[] parameters = func.getParams();
            string parameterString;
            
            for(ulong parIdx = 0; parIdx < parameters.length; parIdx++)
            {
                Variable currentParameter = parameters[parIdx];

                // Extract the variable's type
                Type parameterType = typeChecker.getType(currentParameter.context.container, currentParameter.getType());

                // Generate the symbol-mapped names for the parameters
                Variable typedEntityVariable = cast(Variable)typeChecker.getResolver().resolveBest(func, currentParameter.getName()); //TODO: Remove `auto`
                string renamedSymbol = mapper.symbolLookup(typedEntityVariable);


                // Generate <type> <parameter-name (symbol mapped)>
                parameterString~=typeTransform(parameterType)~" "~renamedSymbol;

                if(parIdx != (parameters.length-1))
                {
                    parameterString~=", ";
                }
            }

            signature~=parameterString;
        }

        // )
        signature~=")";

        // If the function is marked as external then place `extern` infront
        if(func.isExternal())
        {
            signature = "extern "~signature;
        }

        return signature;

    }

    /** 
     * Emits the function prototype for the `Function`
     * of the given name
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     *   functionName = the name of the function
     */
    private void emitFunctionPrototype(File modOut, Module mod, string functionName)
    {
        // Select the function definition code queue by module and function name
        // TODO: Is this needed for protptype def? I think not (REMOVE PLEASE)
        selectQueue(mod, QueueType.FUNCTION_DEF_QUEUE, functionName);

        gprintln("emotFunctionDefinition(): Function: "~functionName~", with "~to!(string)(getSelectedQueueLength())~" many instructions");
    
        //TODO: Look at nested definitions or nah? (Context!!)
        //TODO: And what about methods defined in classes? Those should technically be here too
        Function functionEntity = cast(Function)typeChecker.getResolver().resolveBest(mod, functionName); //TODO: Remove `auto`
        
        // Emit the function signature
        modOut.writeln(generateSignature(functionEntity)~";");
    }

    /** 
     * Emits the function definition for the `Function`
     * of the given name
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     *   functionName = the name of the function
     */
    private void emitFunctionDefinition(File modOut, Module mod, string functionName)
    {
        // Select the function definition code queue by module and function name
        selectQueue(mod, QueueType.FUNCTION_DEF_QUEUE, functionName);

        gprintln("emotFunctionDefinition(): Function: "~functionName~", with "~to!(string)(getSelectedQueueLength())~" many instructions");
    
        //TODO: Look at nested definitions or nah? (Context!!)
        //TODO: And what about methods defined in classes? Those should technically be here too
        Function functionEntity = cast(Function)typeChecker.getResolver().resolveBest(mod, functionName); //TODO: Remove `auto`
        
        // If the Entity is NOT external then emit the signature+body
        if(!functionEntity.isExternal())
        {
            // Emit the function signature
            modOut.writeln(generateSignature(functionEntity));

            // Emit opening curly brace
            modOut.writeln(getCharacter(SymbolType.OCURLY));

            // Emit body
            while(hasInstructions())
            {
                Instruction curFuncBodyInstr = getCurrentInstruction();

                string emit = transform(curFuncBodyInstr);
                gprintln("emitFunctionDefinition("~functionName~"): Emit: "~emit);
                modOut.writeln("\t"~emit);
                
                nextInstruction();
            }

            // Emit closing curly brace
            modOut.writeln(getCharacter(SymbolType.CCURLY));
        }
        // If the Entity IS external then don't emit anything as the signature would have been emitted via a prorotype earlier with `emitPrototypes()`
        else
        {
            // Do nothing
        }
    }

    /** 
     * Emits the code queue of the given `Module`
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     */
    private void emitCodeQueue(File modOut, Module mod)
    {
        // Select the global code queue of the current module
        selectQueue(mod, QueueType.GLOBALS_QUEUE);
        gprintln("Code emittings needed: "~to!(string)(getQueueLength()));

        while(hasInstructions())
        {
            Instruction currentInstruction = getCurrentInstruction();
            modOut.writeln(transform(currentInstruction));

            nextInstruction();
        }

        modOut.writeln();
    }

    /** 
     * Emits the standard imports of the given
     * `Module`
     *
     * Params:
     *   modFile = the `File` to write the emitted source code to
     *   mod = the current `Module` being processed
     */
    private void emitStdint(File modOut, Module mod)
    {
        modOut.writeln("#include<stdint.h>");
    }

    private void emitEntrypoint(File modOut, Module mod)
    {
        gprintln("IMPLEMENT ME", DebugType.ERROR);
        gprintln("IMPLEMENT ME", DebugType.ERROR);
        gprintln("IMPLEMENT ME", DebugType.ERROR);
        gprintln("IMPLEMENT ME", DebugType.ERROR);
        gprintln("We have NOT YET implemented the init method", DebugType.ERROR);

        // modOut.writeln("fok");

        // TODO: In future, for runtime init,
        // I will want to co-opt main(int, args)
        // for use for runtime init to then
        // call ANOTHER REAL main (specified)
        // by the user

        // Therefore there must be some sort
        // of renaming stage somewhere
    }

    private void emitTestingEntrypoint(File modOut, Module mod)
    {
        // TODO: Implement me

        // Test for `simple_functions.t` (function call testing)
        if(cmp(mod.getName(), "simple_functions") == 0)
        {
            modOut.writeln(`
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
        // Test for `simple_function_recursion_factorial.t` (recursive function call testing)
        else if(cmp(mod.getName(), "simple_function_recursion_factorial") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = factorial(3);
    assert(result == 6);
    printf("factorial: %u\n", result);
    
    return 0;
}`);
        }
        // Test for `simple_direct_func_call.t` (statement-level function call)
        else if(cmp(mod.getName(), "simple_direct_func_call") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    // Before it should be 0
    assert(t_de44aff5a74865c97c4f8701d329f28d == 0);

    // Call the function
    function();

    // After it it should be 69
    assert(t_de44aff5a74865c97c4f8701d329f28d == 69);
    
    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_while") == 0)
        {
            modOut.writeln(`
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
        else if(cmp(mod.getName(), "simple_for_loops") == 0)
        {
            modOut.writeln(`
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
        else if(cmp(mod.getName(), "simple_pointer") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_87bc875d0b65f741b69fb100a0edebc7 == 4);
    assert(retValue == 6);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_pointer_array_syntax") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_9d01d71b858651e520c9b503122a1b7a == 4);
    assert(retValue == 6);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_pointer_cast_le") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_e159019f766be1a175186a13f16bcfb7 == 256+4);
    assert(retValue == 256+4+2);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_pointer_malloc") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    test();
    
    // TODO: Test the value

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_extern") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    test();
   
    

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_stack_array_coerce") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 420+69);
    printf("stackArr sum: %d\n", result);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "complex_stack_array_coerce") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 69+420);

    printf("val1: %d\n", t_596f49b2a2784a3c1b073ccfe174caa0);
    printf("val2: %d\n", t_4233b83329676d70ab4afaa00b504564);
    printf("stackArr sum: %d\n", result);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_stack_array_coerce_ptr_syntax") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 420+69);
    printf("stackArr sum: %d\n", result);

    return 0;
}`);
        }
        else if(cmp(mod.getName(), "simple_stack_arrays4") == 0)
        {
            modOut.writeln(`
#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 61);

    return 0;
}`);
        }
        else
        {
            modOut.writeln(`
int main()
{
    return 0;
}
`);
        }
    }

    /** 
     * Performs the compilation step
     *
     * This requires that the `emit()`
     * step must have already been completed
     */
    public override void finalize()
    {
        import tlang.compiler.symbols.data : Program;
        Program program = this.typeChecker.getProgram();
        Module[] programModules = program.getModules();

        string[] srcFiles;
        string[] objectFiles;

        // import tlang.compiler.configuration;
        // config.addConfig(ConfigEntry("dgen:afterexit:clean_c_files", true));
        // config.addConfig(ConfigEntry("dgen:afterexit:clean_obj_files", true));

        scope(exit)
        {
            // Clean up all generated C files
            if(config.hasConfig("dgen:afterexit:clean_c_files") && config.getConfig("dgen:afterexit:clean_c_files").getBoolean())
            {
                foreach(string srcFile; srcFiles)
                {
                    gprintln("Cleaning up source file '"~srcFile~"'...");
                    import std.stdio : remove;
                    remove(srcFile.ptr);

                    if(!remove(srcFile.ptr))
                    {
                        gprintln("There was an error cleaning up source file '"~srcFile~"'"); // TODO: Add error code
                    }
                }
            }

            // Clean up all generates object files
            if(config.hasConfig("dgen:afterexit:clean_obj_files") && config.getConfig("dgen:afterexit:clean_obj_files").getBoolean())
            {
                foreach(string objFile; objectFiles)
                {
                    gprintln("Cleaning up object file '"~objFile~"'...");
                    import std.stdio : remove;
                    remove(objFile.ptr);

                    if(!remove(objFile.ptr))
                    {
                        gprintln("There was an error cleaning up object file '"~objFile~"'"); // TODO: Add error code
                    }
                }
            }
        }

        try
        {
            string systemCompiler = config.getConfig("dgen:compiler").getText();
            gprintln("Using system C compiler '"~systemCompiler~"' for compilation");

            // Check for object files to be linked in
            string[] objectFilesLink;
            if(config.hasConfig("linker:link_files"))
            {
                objectFilesLink = config.getConfig("linker:link_files").getArray();
                gprintln("Object files to be linked in: "~to!(string)(objectFilesLink));
            }
            else
            {
                gprintln("No files to link in");
            }


            // TODO: Do for-each generation of `.o` files here with `-c`
            foreach(Module curMod; programModules)
            {
                string modFileSrcPath = format("%s.c", curMod.getName());
                srcFiles ~= modFileSrcPath;
                string modFileObjPath = format("%s.o", curMod.getName());

                string[] args = [systemCompiler, "-c", modFileSrcPath, "-o", modFileObjPath];

                gprintln("Compiling now with arguments: "~to!(string)(args));

                Pid ccPID = spawnProcess(args);
                int code = wait(ccPID);
                if(code)
                {
                    //NOTE: Make this a TLang exception
                    throw new Exception("The CC exited with a non-zero exit code ("~to!(string)(code)~")");
                }

                // Only add it to the list of files if it was generated
                // (this guards against the clean up routines spitting out errors
                // for object files which were never generated in the first place)
                objectFiles ~= modFileObjPath;
            }

            // Now determine the entry point module
            // Module entryModule;
            // Function _;
            // if(findEntrypoint(entryModule, _))
            // {
                
            // }

            // Perform linking
            string[] args = [systemCompiler];

            // Tack on all generated object files
            args ~= objectFiles;

            // Tack on any objects to link that were specified in Config
            args ~= objectFilesLink;

            // Tack on the output filename (TODO: Fix the output file name)
            args ~= ["-o", "./tlang.out"]; 

            

            // Now link all object files (the `.o`'s) together
            // and perform linking
            Pid ccPID = spawnProcess(args);
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

import tlang.compiler.symbols.data : Entity, AccessorType;
import niknaks.functional : Predicate, predicateOf;

/** 
 * Derives a closure predicate which captires
 * the provided access modifier type and will
 * apply a logic which disregards any non-`Function`
 * `Entity`, however if a `Function`-typed entity
 * IS found then it will determine if its access
 * modifier matches that of the provided one
 *
 * Params:
 *   accModType = the access modifier to filter
 * by
 *
 * Returns: a `Predicate!(Entity)`
 */
private Predicate!(Entity) derive_functionAccMod(AccessorType accModType)
{
    bool match(Entity entity)
    {
        Function func = cast(Function)entity;

        // Disregard any non-Function
        if(func is null)
        {
            return false;
        }
        // Onyl care about those with a matching
        // modifier
        else
        {
            return func.getAccessorType() == accModType;
        }
    }

    return &match;
}

/** 
 * Derives a closure predicate which captires
 * the provided access modifier type and will
 * apply a logic which disregards any non-`Variable`
 * `Entity`, however if a `Variable`-typed entity
 * IS found then it will determine if its access
 * modifier matches that of the provided one
 *
 * Params:
 *   accModType = the access modifier to filter
 * by
 *
 * Returns: a `Predicate!(Entity)`
 */
private Predicate!(Entity) derive_variableAccMod(AccessorType accModType)
{
    bool match(Entity entity)
    {
        Variable var = cast(Variable)entity;

        // Disregard any non-Variable
        if(var is null)
        {
            return false;
        }
        // Onyl care about those with a matching
        // modifier
        else
        {
            return var.getAccessorType() == accModType;
        }
    }

    return &match;
}