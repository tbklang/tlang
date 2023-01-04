module compiler.typecheck.core;

import compiler.symbols.check;
import compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import compiler.parsing.core;
import compiler.typecheck.resolution;
import compiler.typecheck.exceptions;
import compiler.symbols.typing.core;
import compiler.typecheck.dependency.core;
import compiler.codegen.instruction;
import std.container.slist;
import std.algorithm : reverse;

/**
* The Parser only makes sure syntax
* is adhered to (and, well, partially)
* as it would allow string+string
* for example
*
*/
public final class TypeChecker
{
    private Module modulle;

    /* The name resolver */
    private Resolver resolver;

    public Module getModule()
    {
        return modulle;
    }

    this(Module modulle)
    {
        this.modulle = modulle;
        resolver = new Resolver(this);
        /* TODO: Module check?!?!? */
    }

    /**
    * I guess this should be called rather
    * when processing assignments but I also
    * think we need something like it for
    * class initializations first rather than
    * variable expressions in assignments 
    * (which should probably use some other
    * function to check that then)
    */
    public void dependencyCheck()
    {
        /* Check declaration and definition types */
        checkDefinitionTypes(modulle);

        /* TODO: Implement me */
        checkClassInherit(modulle);


        /**
        * Dependency tree generation
        *
        * Currently this generates a dependency tree
        * just for the module, the tree must be run
        * through after wards to make it
        * non-cyclic
        *
        */

        // Allow Context class access to the type checker (used in Instruction where only Context is available)
        Context.tc = this;

        // Allow the SymbolMapper class to access the type checker
        import compiler.codegen.mapper : SymbolMapper;
        SymbolMapper.tc = this;

        // DNodeGenerator.staticTC = this;
        

        DNodeGenerator dNodeGenerator = new DNodeGenerator(this);
        DNode rootNode = dNodeGenerator.generate(); /* TODO: This should make it acyclic */

        /* Print the tree */
        string tree = rootNode.print();
        gprintln(tree);


        /* Get the action-list (linearised bottom up graph) */
        DNode[] actionList = rootNode.poes;
        doTypeCheck(actionList);        
        printTypeQueue();

        /**
         * After processing globals executions the instructions will
         * be placed into `codeQueue`, therefore copy them from the temporary
         * scratchpad queue into `globalCodeQueue`.
         *
         * Then clean the codeQueue for next use
         */
        foreach(Instruction curGlobInstr; codeQueue)
        {
            globalCodeQueue~=curGlobInstr;
        }
        codeQueue.clear();
        assert(codeQueue.empty() == true);

        //FIXME: Look at this, ffs why is it static
        //Clear tree/linearized version (todo comment)
        DNode.poes=[];

        /* Grab functionData ??? */
        FunctionData[string] functionDefinitions = grabFunctionDefs();
        gprintln("Defined functions: "~to!(string)(functionDefinitions));

        foreach(FunctionData funcData; functionDefinitions.values)
        {
            assert(codeQueue.empty() == true);


            DNode funcNode = funcData.generate();
            //NOTE: We need to call this, it generates tree but also does the linearization
            //NOTE: Rename that
            funcNode.print();
            DNode[] actionListFunc = funcNode.poes;

            //TODO: Would this not mess with our queues?
            doTypeCheck(actionListFunc);
            printTypeQueue();
            gprintln(funcNode.print());

            // The current code queue would be the function's body instructions
            // a.k.a. the `codeQueue`
            // functionBodies[funcData.name] = codeQueue;


            // The call to `doTypeCheck()` above adds to this queue
            // so we should clean it out before the next run
            //
            // NOTE: Static allocations in? Well, we don't clean init queue
            // so is it fine then? We now have seperate dependency trees,
            // we should make checking methods that check the `initQueue`
            // whenever we come past a `ClassStaticNode` for example
            // codeQueue.clear();

            /**
             * Copy over the function code queue into
             * the function code queue respective key.
             *
             * Then clear the scratchpad code queue
             */
            functionBodyCodeQueues[funcData.name]=[];
            foreach(Instruction curFuncInstr; codeQueue)
            {
                //TODO: Think about class funcs? Nah
                functionBodyCodeQueues[funcData.name]~=curFuncInstr;
                gprintln("FuncDef ("~funcData.name~"): Adding body instruction: "~to!(string)(curFuncInstr));
            }
            codeQueue.clear();

            // Clear the linearization for the next round
            DNode.poes=[];

            gprintln("FUNCDEF DONE: "~to!(string)(functionBodyCodeQueues[funcData.name]));
        }

        
    }


    /** 
     * Function definitions
     *
     * Holds their action lists which are to be used for the
     * (later) emitting of their X-lang emit code
     */
     //FUnctionDeifnition should couple `linearizedList` but `functionEntity`
    // private FunctionDefinition[string] functionDefinitions2; //TODO: Use this



    /** 
     * Concrete queues
     *
     * These queues below are finalized and not used as a scratchpad.
     *
     * 1. Global code queue
     *     - This accounts for the globals needing to be executed
     * 2. Function body code queues
     *     - This accounts for (every) function definition's code queue
     */
    private Instruction[] globalCodeQueue;
    private Instruction[][string] functionBodyCodeQueues;

    public Instruction[] getGlobalCodeQueue()
    {
        return globalCodeQueue;
    }

    public Instruction[][string] getFunctionBodyCodeQueues()
    {
        return functionBodyCodeQueues;
    }


    


    /* Main code queue (used for temporary passes) */
    private SList!(Instruction) codeQueue; //TODO: Rename to `currentCodeQueue`

    /* Initialization queue */
    private SList!(Instruction) initQueue;


    //TODO: CHange to oneshot in the function
    public Instruction[] getInitQueue()
    {
        Instruction[] initQueueConcrete;

        foreach(Instruction currentInstruction; initQueue)
        {
            initQueueConcrete~=currentInstruction;
        }

        return initQueueConcrete;
    }

    /* Adds an initialization instruction to the initialization queue (at the back) */
    public void addInit(Instruction initInstruction)
    {
        initQueue.insertAfter(initQueue[], initInstruction);
    }

    /*
    * Prints the current contents of the init-queue
    */
    public void printInitQueue()
    {
        import std.range : walkLength;
        ulong i = 0;
        foreach(Instruction instruction; initQueue)
        {
            gprintln("InitQueue: "~to!(string)(i+1)~"/"~to!(string)(walkLength(initQueue[]))~": "~instruction.toString());
            i++;
        }
    }

    /* Adds an instruction to the front of code queue */
    public void addInstr(Instruction inst)
    {
        codeQueue.insert(inst);
    }

    /* Adds an instruction to the back of the code queue */
    public void addInstrB(Instruction inst)
    {
        codeQueue.insertAfter(codeQueue[], inst);
    }

    /* Removes the instruction at the front of the code queue and returns it */
    public Instruction popInstr()
    {
        Instruction poppedInstr;

        if(!codeQueue.empty)
        {
            poppedInstr = codeQueue.front();
            codeQueue.removeFront();
        }
        
        return poppedInstr;
    }

    /* Pops from the tail of the code queue and returns it */
    public Instruction tailPopInstr()
    {
        Instruction poppedInstr;

        if(!codeQueue.empty)
        {
            // Perhaps there is a nicer way to tail popping
            codeQueue.reverse();
            poppedInstr = codeQueue.front();
            codeQueue.removeFront();
            codeQueue.reverse();
        }

        return poppedInstr;
    }

    public bool isInstrEmpty()
    {
        return codeQueue.empty;
    }
    
    // public Instruction[] getCodeQueue()
    // {
    //     Instruction[] codeQueueConcrete;

    //     foreach(Instruction currentInstruction; codeQueue)
    //     {
    //         codeQueueConcrete~=currentInstruction;
    //     }

    //     return codeQueueConcrete;
    // }

    /*
    * Prints the current contents of the code-queue
    */
    public void printCodeQueue()
    {
        import std.range : walkLength;
        ulong i = 0;
        foreach(Instruction instruction; codeQueue)
        {
            gprintln(to!(string)(i+1)~"/"~to!(string)(walkLength(codeQueue[]))~": "~instruction.toString());
            i++;
        }
    }

    /*
    * Prints the current contents of the code-queue
    */
    public void printTypeQueue()
    {
        import std.range : walkLength;
        ulong i = 0;
        foreach(Type instruction; typeStack)
        {
            gprintln("TypeQueue: "~to!(string)(i+1)~"/"~to!(string)(walkLength(typeStack[]))~": "~instruction.toString());
            i++;
        }
    }

    /**
    * There are several types and comparing them differs
    */
    private bool isSameType(Type type1, Type type2)
    {
        bool same = false;

        

        /* Handling for Integers */
        if(typeid(type1) == typeid(type2) && cast(Integer)type1 !is null)
        {
            Integer i1 = cast(Integer)type1, i2 = cast(Integer)type2;

            /* Both same size? */
            if(i1.getSize() == i2.getSize())
            {
                /* Matching signedness ? */
                same =  i1.isSigned() == i2.isSigned();
            }
            /* Size mismatch */
            else
            {
                same = false;
            }
        }


        gprintln("isSameType("~to!(string)(type1)~","~to!(string)(type2)~"): "~to!(string)(same), DebugType.ERROR);
        return same;
    }



    private SList!(Type) typeStack;


    /**
    * Adds a Type to the type queue right at the beginning
    * of it
    */
    private void addType(Type typeName)
    {
        typeStack.insert(typeName);
    }

    /**
    * Adds a Type to the type queue right at the end
    * of it
    */
    private void addTypeB(Type typeName)
    {
        typeStack.insertAfter(typeStack[], typeName);
    }

    private Type popType()
    {
        Type typeCur = typeStack.front();
        
        typeStack.removeFront();

        return typeCur;
    }

    public bool isTypesEmpty()
    {
        return typeStack.empty;
    }

    public void typeCheckThing(DNode dnode)
    {
        gprintln("typeCheckThing(): "~dnode.toString());

        /* ExpressionDNodes */
        if(cast(compiler.typecheck.dependency.expression.ExpressionDNode)dnode)
        {
            compiler.typecheck.dependency.expression.ExpressionDNode expDNode = cast(compiler.typecheck.dependency.expression.ExpressionDNode)dnode;

            Statement statement = expDNode.getEntity();
            gprintln("Hdfsfdjfds"~to!(string)(statement));

            /* Dependent on the type of Statement */

            if(cast(NumberLiteral)statement)
            {
                /* TODO: For now */

                /**
                * Typechecking
                *
                * If the number literal contains a `.` then it is a float
                * else if is an int (NOTE: This may need to be more specific
                * with literal encoders down the line)
                */
                NumberLiteral numLit = cast(NumberLiteral)statement;
                import std.string : indexOf;
                bool isFloat = indexOf(numLit.getNumber(), ".") > -1; 
                gprintln("NUMBER LIT: isFloat: "~to!(string)(isFloat));
                addType(getType(modulle, isFloat ? "float" : "int"));

                /**
                * Codegen
                *
                * TODO: We just assume (for integers) byte size 4?
                * 
                * Generate the correct value instruction depending
                * on the number literal's type
                */
                Value valInstr;

                /* Generate a LiteralValue (Integer literal) */
                if(!isFloat)
                {
                    ulong i = to!(ulong)((cast(NumberLiteral)statement).getNumber());
                    LiteralValue litValInstr = new LiteralValue(i, 4);

                    valInstr = litValInstr;
                }
                /* Generate a LiteralValueFloat (Floating point literal) */
                else
                {
                    double i = to!(float)((cast(NumberLiteral)statement).getNumber());
                    LiteralValueFloat litValInstr = new LiteralValueFloat(i, 4);

                    valInstr = litValInstr;
                }
                
                addInstr(valInstr);
            }
            /* String literal */
            else if(cast(StringExpression)statement)
            {
                gprintln("Typecheck(): String literal processing...");

                /**
                * Add the char* type as string literals should be
                * interned
                */
                addType(getType(modulle, "char*"));
                
                /**
                * Add the instruction and pass the literal to it
                */
                StringExpression strExp = cast(StringExpression)statement;
                string strLit = strExp.getStringLiteral();
                gprintln("String literal: `"~strLit~"`");
                StringLiteral strLitInstr = new StringLiteral(strLit);
                addInstr(strLitInstr);

                gprintln("Typecheck(): String literal processing... [done]");
            }
            else if(cast(VariableExpression)statement)
            {

                gprintln("Yaa, it's rewind time");
                auto g  = cast(VariableExpression)statement;

                /* FIXME: It would seem that g.getContext() is returning null, so within function body's context is not being set */
                gprintln("VarExp: "~g.getName());
                gprintln(g.getContext());
                auto gVar = cast(TypedEntity)resolver.resolveBest(g.getContext().getContainer(), g.getName());
                gprintln("gVar nullity?: "~to!(string)(gVar is null));

                /* TODO; Above crashes when it is a container, eish baba - from dependency generation with `TestClass.P.h` */

                string variableName = resolver.generateName(modulle, gVar);

                gprintln("VarName: "~variableName);
                gprintln("Halo");

                gprintln("Yaa, it's rewind time1: "~to!(string)(gVar.getType()));
                gprintln("Yaa, it's rewind time2: "~to!(string)(gVar.getContext()));
                
                /* TODO: Above TYpedEntity check */
                /* TODO: still wip the expresison parser */

                /* TODO: TYpe needs ansatz too `.updateName()` call */
                addType(getType(gVar.getContext().getContainer(), gVar.getType()));

                gprintln("Yaa, it's rewind time");


                /**
                * Codegen
                *
                * FIXME: Add type info, length
                *
                * 1. Generate the instruction
                * 2. Set the Context of it to where the VariableExpression occurred
                */
                FetchValueVar fVV = new FetchValueVar(variableName, 4);
                fVV.context = g.getContext();


                addInstr(fVV);
            }
            // else if(cast()) !!!! Continue here 
            else if(cast(BinaryOperatorExpression)statement)
            {
                BinaryOperatorExpression binOpExp = cast(BinaryOperatorExpression)statement;
                SymbolType binOperator = binOpExp.getOperator();
                

                /**
                * Typechecking (TODO)
                */
                Type vRhsType = popType();
                Type vLhsType = popType();

                /**
                * TODO:
                * Types must either BE THE SAME or BE COMPATIBLE
                */
                if(isSameType(vLhsType, vRhsType))
                {
                    /* Left type + Right type = left/right type (just use left - it doesn't matter) */
                    addType(vLhsType);
                }
                else
                {
                    gprintln("Binary operator expression requires both types be same, but got '"~vRhsType.toString()~"' and '"~vLhsType.toString()~"'", DebugType.ERROR);
                    assert(false);
                }
                

                /**
                * Codegen
                *
                * Retrieve the two Value Instructions
                *
                * They would be placed as if they were on stack
                * hence we need to burger-flip them around (swap)
                */
                Instruction vRhsInstr = popInstr();
                Instruction vLhsInstr = popInstr();
                
                BinOpInstr addInst = new BinOpInstr(vLhsInstr, vRhsInstr, binOperator);
                addInstr(addInst);
            }
            /* Unary operator expressions */
            else if(cast(UnaryOperatorExpression)statement)
            {
                UnaryOperatorExpression unaryOpExp = cast(UnaryOperatorExpression)statement;
                SymbolType unaryOperator = unaryOpExp.getOperator();
                

                

                /**
                * Typechecking (TODO)
                */
                Type expType = popType();

                /* TODO: Ad type check for operator */

                /* If the unary operation is an arithmetic one */
                if(unaryOperator == SymbolType.ADD || unaryOperator == SymbolType.SUB)
                {
                    /* TODO: I guess any type fr */
                }
                /* If pointer dereference */
                else if(unaryOperator == SymbolType.STAR)
                {
                    /* TODO: Add support */
                }
                /* If pointer create `&` */
                else if(unaryOperator == SymbolType.AMPERSAND)
                {
                    /* TODO: Should we make a PointerFetchInstruction maybe? */
                    /* Answer: Nah, waste of Dtype, we have needed information */

                    /**
                    * NOTE:
                    *
                    * We are going to end up here with `unaryOpExp` being a `FetchVarInstr`
                    * which I guess I'd like to, not rework but pull data out of and put
                    * some pointer fetch, infact surely the whole instruction we return
                    * can be a subset of UnaryOpInstruction just for the pointer case
                    *
                    * I think it is important we obtain Context, Name, Type of variable
                    * (so that we can construct the Type* (the pointer type))
                    */
                    gprintln("ExpType: "~expType.toString());
                }
                /* This should never occur */
                else
                {
                    gprintln("UnaryOperatorExpression: This should NEVER happen: "~to!(string)(unaryOperator), DebugType.ERROR);
                    assert(false);
                }
                

                /**
                * Codegen
                *
                * Retrieve the instruction
                *
                */
                Instruction expInstr = popInstr();
                
                
                UnaryOpInstr addInst = new UnaryOpInstr(expInstr, unaryOperator);
                addInstr(addInst);
            }
            /* Function calls */
            else if(cast(FunctionCall)statement)
            {
                // gprintln("FuncCall hehe (REMOVE AFTER DONE)");
                // printTypeQueue();

                FunctionCall funcCall = cast(FunctionCall)statement;

                /* TODO: Look up func def to know when popping stops (types-based delimiting) */
                Function func = cast(Function)resolver.resolveBest(modulle, funcCall.getName());
                assert(func);
                VariableParameter[] paremeters = func.getParams();


                /* TODO: Pass in FUnction, so we get function's body for calling too */
                FuncCallInstr funcCallInstr = new FuncCallInstr(func.getName(), paremeters.length);
                gprintln("Name of func call: "~func.getName(), DebugType.ERROR);

                /* If there are paremeters for this function (as per definition) */
                if(!paremeters.length)
                {
                    gprintln("No parameters for deez nuts: "~func.getName(), DebugType.ERROR);
                }
                /* Pop all args per type */
                else
                {
                    ulong parmCount = paremeters.length-1;
                    gprintln("Kachow: "~to!(string)(parmCount),DebugType.ERROR);

                    while(!isInstrEmpty())
                    {
                        Instruction instr = popInstr();
                        
                        Value valueInstr = cast(Value)instr;
                        

                        /* Must be a value instruction */
                        if(valueInstr && parmCount!=-1)
                        {
                            /* TODO: Determine type and match up */
                            gprintln("Yeah");
                            gprintln(valueInstr);
                            Type argType = popType();
                            // gprintln(argType);

                            Variable parameter = paremeters[parmCount];
                            // gprintln(parameter);
                            

                            Type parmType = getType(func.parentOf(), parameter.getType());
                            // gprintln("FuncCall(Actual): "~argType.getName());
                            // gprintln("FuncCall(Formal): "~parmType.getName());
                            // gprintln("FuncCall(Actual): "~valueInstr.toString());


                            // printTypeQueue();
                            /* Match up types */
                            //if(argType == parmType)
                            if(isSameType(argType, parmType))
                            {
                                gprintln("Match type");

                                /* Add the instruction into the FunctionCallInstr */
                                funcCallInstr.setEvalInstr(parmCount, valueInstr);
                                gprintln(funcCallInstr.getEvaluationInstructions());
                            }
                            else
                            {
                                printCodeQueue();
                                gprintln("Wrong actual argument type for function call", DebugType.ERROR);
                                gprintln("Cannot pass value of type '"~argType.getName()~"' to function accepting '"~parmType.getName()~"'", DebugType.ERROR);
                                assert(false);
                            }

                            parmCount--;
                        }
                        else
                        {
                            /* Push it back */
                            addInstr(instr);
                            break;
                        }
                    }
                }

                
                
                

                /**
                * TODO:
                *
                * 1. Create FuncCallInstr
                * 2. Evaluate args and process them?! wait done elsewhere yeah!!!
                * 3. Pop arts into here
                * 4. AddInstr(combining those args)
                * 5. DOne
                */
                funcCallInstr.context = funcCall.getContext();

                addInstr(funcCallInstr);
                addType(getType(func.parentOf(), func.getType()));
            }
        }
        /* VariableAssigbmentDNode */
        else if(cast(compiler.typecheck.dependency.variables.VariableAssignmentNode)dnode)
        {
            import compiler.typecheck.dependency.variables;

            /* Get the variable's name */
            string variableName;
            VariableAssignmentNode varAssignDNode = cast(compiler.typecheck.dependency.variables.VariableAssignmentNode)dnode;
            Variable assignTo = (cast(VariableAssignment)varAssignDNode.getEntity()).getVariable();
            variableName = resolver.generateName(modulle, assignTo);
            gprintln("VariableAssignmentNode: "~to!(string)(variableName));

            /* Get the Context of the Variable Assigmnent */
            Context variableAssignmentContext = (cast(VariableAssignment)varAssignDNode.getEntity()).context;


            /**
            * FIXME: Now with ClassStaticAllocate we will have wrong instructoins for us
            * ontop of the stack (at the beginning of the queue), I think this leads us
            * to potentially opping wrong thing off - we should filter pop perhaps
            */

            /**
            * Codegen
            *
            * 1. Get the variable's name
            * 2. Pop Value-instruction
            * 3. Generate VarAssignInstruction with Value-instruction
            * 4. Set the VarAssignInstr's Context to that of the Variable assigning to
            */
            Instruction valueInstr = popInstr();
            gprintln("VaribleAssignmentNode(): Just popped off valInstr?: "~to!(string)(valueInstr), DebugType.WARNING);
            gprintln(valueInstr is null);/*TODO: FUnc calls not implemented? Then is null for simple_1.t */
            VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
            varAssInstr.context = variableAssignmentContext;
            
            addInstr(varAssInstr);
        }
        /* TODO: Add support */
        /**
        * TODO: We need to emit different code dependeing on variable declaration TYPE
        * We could use context for this, ClassVariableDec vs ModuleVariableDec
        */
        else if(cast(compiler.typecheck.dependency.variables.StaticVariableDeclaration)dnode)
        {
            /* TODO: Add skipping if context is within a class */
            /* We need to wait for class static node, to do an InitInstruction (static init) */
            /* It probably makes sense , IDK, we need to allocate both classes */

            /**
            * Codegen
            *
            * Emit a variable declaration instruction
            */
            Variable variablePNode = cast(Variable)dnode.getEntity();
            gprintln("HELLO FELLA");
            string variableName = resolver.generateName(modulle, variablePNode);
            gprintln("HELLO FELLA (name): "~variableName);
            


            // CHeck if this variable declaration has an assignment attached
            VariableAssignmentInstr assignmentInstr;
            if(variablePNode.getAssignment())
            {
                Instruction poppedInstr = popInstr();
                assignmentInstr = cast(VariableAssignmentInstr)poppedInstr;
                assert(assignmentInstr);
            }


            VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4, variablePNode.getType(), assignmentInstr);

            /* NEW CODE (9th November 2021) Set the context */
            varDecInstr.context = variablePNode.context;


            addInstrB(varDecInstr);

            
            
            
        }
        /* TODO: Add class init, see #8 */
        else if(cast(compiler.typecheck.dependency.classes.classStaticDep.ClassStaticNode)dnode)
        {
            /* Extract the class node and create a static allocation instruction out of it */
            Clazz clazzPNode = cast(Clazz)dnode.getEntity();
            string clazzName = resolver.generateName(modulle, clazzPNode);
            ClassStaticInitAllocate clazzStaticInitAllocInstr = new ClassStaticInitAllocate(clazzName);

            /* Add this static initialization to the list of global allocations required */
            addInit(clazzStaticInitAllocInstr);
        }
        /* It will pop a bunch of shiiit */
        /* TODO: ANy statement */
        else if(cast(compiler.typecheck.dependency.core.DNode)dnode)
        {
            /* TODO: Get the STatement */
            Statement statement = dnode.getEntity();

            gprintln("Generic DNode typecheck(): Begin (examine: "~to!(string)(dnode)~" )");


            /* VariableAssignmentStdAlone */
            if(cast(VariableAssignmentStdAlone)statement)
            {
                VariableAssignmentStdAlone vasa = cast(VariableAssignmentStdAlone)statement;
                string variableName = vasa.getVariableName();

                /**
                * Codegen
                *
                * 1. Get the variable's name
                * 2. Pop Value-instruction
                * 3. Generate VarAssignInstruction with Value-instruction
                */
                Instruction valueInstr = popInstr();
                VariableAssignmentInstr vAInstr = new VariableAssignmentInstr(variableName, valueInstr);

                /* Set the VariableAssigmmentInstruction's context to that of the stdalone entity */
                vAInstr.context = vasa.getContext();

                addInstrB(vAInstr);

                gprintln("VariableAssignmentStdAlone", DebugType.ERROR);
            }
            /**
            * Return statement (ReturnStmt)
            */
            else if(cast(ReturnStmt)statement)
            {
                ReturnStmt returnStatement = cast(ReturnStmt)statement;

                /**
                * Codegen
                *
                * 1. Pop the expression on the stack
                * 2. Create a new ReturnInstruction with the expression instruction
                * embedded in it
                * 3. Set the Context of the instruction
                * 4. Add this instruction back
                */
                Value returnExpressionInstr = cast(Value)popInstr();
                assert(returnExpressionInstr);
                ReturnInstruction returnInstr = new ReturnInstruction(returnExpressionInstr);
                returnInstr.context = returnStatement.getContext();
                addInstrB(returnInstr);
            }
            /**
            * If statement (IfStatement)
            */
            else if(cast(IfStatement)statement)
            {
                IfStatement ifStatement = cast(IfStatement)statement;
                BranchInstruction[] branchInstructions;

                /* Get the if statement's branches */
                Branch[] branches = ifStatement.getBranches();
                assert(branches.length > 0);

                /**
                * 1. These would be added stack wise, so we need to pop them like backwards
                * 2. Then a reversal at the end (generated instructions list)
                *
                * FIXME: EIther used siggned or the hack below lmao, out of boounds
                */
                for(ulong branchIdx = branches.length-1; true; branchIdx--)
                {
                    Branch branch = branches[branchIdx];

                    // Pop off an expression instruction (if it exists)
                    Value branchConditionInstr;
                    if(branch.hasCondition())
                    {
                        Instruction instr = popInstr();
                        gprintln("BranchIdx: "~to!(string)(branchIdx));
                        gprintln("Instr is: "~to!(string)(instr));
                        branchConditionInstr = cast(Value)instr;
                        assert(branchConditionInstr);
                    }

                    // Get the number of body instructions to pop
                    ulong bodyCount = branch.getBody().length;
                    ulong i = 0;
                    Instruction[] bodyInstructions;

                    
                    while(i < bodyCount)
                    {
                        Instruction bodyInstr = tailPopInstr();
                        bodyInstructions~=bodyInstr;

                        gprintln("tailPopp'd("~to!(string)(i)~"/"~to!(string)(bodyCount-1)~"): "~to!(string)(bodyInstr));

                        i++;
                    }

                    // Reverse the body instructions (correct ordering)
                    bodyInstructions=reverse(bodyInstructions);

                    // Create the branch instruction (coupling the condition instruction and body instructions)
                    branchInstructions~=new BranchInstruction(branchConditionInstr, bodyInstructions);

                    

                    if(branchIdx == 0)
                    {
                        break;
                    }
                }

                // Reverse the list to be in the correct order (it was computed backwards)
                branchInstructions=reverse(branchInstructions);

                /**
                * Code gen
                *
                * 1. Create the IfStatementInstruction containing the BranchInstruction[](s)
                * 2. Set the context
                * 3. Add the instruction
                */
                IfStatementInstruction ifStatementInstruction = new IfStatementInstruction(branchInstructions);
                ifStatementInstruction.context = ifStatement.getContext();
                addInstrB(ifStatementInstruction);

                gprintln("If!");
            }
            /**
            * While loop (WhileLoop)
            */
            else if(cast(WhileLoop)statement)
            {
                WhileLoop whileLoop = cast(WhileLoop)statement;

                Branch branch = whileLoop.getBranch();

                /* The condition `Value` instruction should be on the stack */
                Value valueInstrCondition = cast(Value)popInstr();
                assert(valueInstrCondition);

                /* Process the body of the while-loop with tail-popping followed by a reverse */
                Instruction[] bodyInstructions;
                ulong bodyLen = branch.getBody().length;
                ulong bodyIdx = 0;
            
                while(bodyIdx < bodyLen)
                {
                    Instruction bodyInstr = tailPopInstr();
                    bodyInstructions~=bodyInstr;
                    bodyIdx++;
                }

                // Reverse the list to be in the correct order (it was computed backwards)
                bodyInstructions=reverse(bodyInstructions);


                // Create a branch instruction coupling the condition instruction + body instructions (in corrected order)
                BranchInstruction branchInstr = new BranchInstruction(valueInstrCondition, bodyInstructions);


                /**
                * Code gen
                *
                * 1. Create the WhileLoopInstruction containing the BranchInstruction
                * 2. Set the context
                * 3. Add the instruction
                */
                WhileLoopInstruction whileLoopInstruction = new WhileLoopInstruction(branchInstr);
                whileLoopInstruction.context = whileLoop.getContext();
                addInstrB(whileLoopInstruction);
            }
            /* Branch */
            else if(cast(Branch)statement)
            {
                Branch branch = cast(Branch)statement;

                gprintln("Look at that y'all, cause this is it: "~to!(string)(branch));
            }
            /* Case of no matches */
            else
            {
                gprintln("NO MATCHES FIX ME FOR: "~to!(string)(statement), DebugType.WARNING);
            }
        }
        


    }

    /**
    * Perform type-checking and code-generation
    * on the provided linearized dependency tree
    */
    private void doTypeCheck(DNode[] actionList)
    {
        /* Print the action list provided to us */
        gprintln("Action list: "~to!(string)(actionList));

        /**
        * Loop through each dependency-node in the action list
        * and perform the type-checking/code generation
        */
        foreach(DNode node; actionList)
        {
            gprintln("Process: "~to!(string)(node));

            /* Print the code queue each time */
            gprintln("sdfhjkhdsfjhfdsj 1");
            printCodeQueue();
            gprintln("sdfhjkhdsfjhfdsj 2");

            /* Type-check/code-gen this node */
            typeCheckThing(node);
            writeln("--------------");
        }


        writeln("\n################# Results from type-checking/code-generation #################\n");

        
        /* Print the init queue */
        gprintln("<<<<< FINAL ALLOCATE QUEUE >>>>>");
        printInitQueue();

        /* Print the code queue */
        gprintln("<<<<< FINAL CODE QUEUE >>>>>");
        printCodeQueue();
    }

    /**
    * Given a type as a string this
    * returns the actual type
    *
    * If not found then null is returned
    */
    public Type getType(Container c, string typeString)
    {
        Type foundType;

        /* Check if the type is built-in */
        foundType = getBuiltInType(this, typeString);

        /* If it isn't then check for a type (resolve it) */
        if(!foundType)
        {
            foundType = cast(Type)resolver.resolveBest(c, typeString);
        }
        
        return foundType;
    }

    /* TODO: TYpeEntity check sepeare */
    /* TODO: Parsing within function etc. */

    private void checkDefinitionTypes(Container c)
    {
        /* Check variables and functions (TypedEntities) declarations */
        // checkTypedEntitiesTypeNames(c);

       

        /* Check class inheritance types */
        Clazz[] classes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classes ~= cast(Clazz) statement;
            }
        }
    }

    /**
    * Begins the type checking process
    */
    public void beginCheck()
    {
        /**
        * Make sure there are no name collisions anywhere
        * in the Module with an order of precedence of
        * Classes being declared before Functions and
        * Functions before Variables
        */
        checkContainerCollision(modulle); /* TODO: Rename checkContainerCollision */

        /* TODO: Now that everything is defined, no collision */
        /* TODO: Do actual type checking and declarations */
        dependencyCheck();
    }

    private void checkClassInherit(Container c)
    {
        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classTypes ~= cast(Clazz) statement;
            }
        }

        /* Process each Clazz */
        foreach (Clazz clazz; classTypes)
        {
            /* Get the current class's parent */
            string[] parentClasses = clazz.getInherit();
            gprintln("Class: " ~ clazz.getName() ~ ": ParentInheritList: " ~ to!(
                    string)(parentClasses));

            /* Try resolve all of these */
            foreach (string parent; parentClasses)
            {
                /* Find the named entity */
                Entity namedEntity;

                /* Check if the name is rooted */
                string[] dotPath = split(parent, '.');
                gprintln(dotPath.length);

                /* Resolve the name */
                namedEntity = resolver.resolveBest(c, parent);

                /* If the entity exists */
                if (namedEntity)
                {
                    /* Check if it is a Class, if so non-null */
                    Clazz parentEntity = cast(Clazz) namedEntity;

                    /* Only inherit from class or (TODO: interfaces) */
                    if (parentEntity)
                    {
                        /* Make sure it is not myself */
                        if (parentEntity != clazz)
                        {
                            /* TODO: Add loop checking here */
                        }
                        else
                        {
                            Parser.expect("Cannot inherit from self");
                        }
                    }
                    /* Error */
                else
                    {
                        Parser.expect("Can only inherit from classes");
                    }
                }
                /* If the entity doesn't exist then it is an error */
                else
                {
                    Parser.expect("Could not find any entity named " ~ parent);
                }
            }
        }

        /* Once processing is done, apply recursively */
        foreach (Clazz clazz; classTypes)
        {
            checkClassInherit(clazz);
        }

    }

    private void checkClasses(Container c)
    {
        /**
        * Make sure no duplicate types (classes) defined
        * within same Container
        */
        checkClassNames(c);

        /**
        * Now that everything is neat and tidy
        * let's check class properties like inheritance
        * names
        */
        checkClassInherit(c);
    }

    public Resolver getResolver()
    {
        return resolver;
    }

    /**
    * Given a Container `c` this will check all
    * members of said Container and make sure
    * none of them have a name that conflicts
    * with any other member in said Container
    * nor uses the same name AS the Container
    * itself.
    *
    * Errors are printed when a member has a name
    * of a previously defined member
    *
    * Errors are printed if the memeber shares a
    * name with the container
    *
    * If the above 2 are false then a last check
    * happens to check if the current Entity
    * that just passed these checks is itself a
    * Container, if not, then we do nothing and
    * go onto processing the next Entity that is
    * a member of Container `c` (we stay at the
    * same level), HOWEVER if so, we then recursively
    * call `checkContainer` on said Entity and the
    * logic above applies again
    */
    private void checkContainerCollision(Container c)
    {
        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity)c;
        assert(containerEntity);

        /**
        * Get all Entities of the Container with order Clazz, Function, Variable
        */
        Entity[] entities = getContainerMembers(c);
        gprintln("checkContainer(C): " ~ to!(string)(entities));

        foreach (Entity entity; entities)
        {
            /**
            * Absolute root Container (in other words, the Module)
            * can not be used
            */
            if(cmp(modulle.getName(), entity.getName()) == 0)
            {
                throw new CollidingNameException(this, modulle, entity, c);
            }
            /**
            * If the current entity's name matches the container then error
            */
            else if (cmp(containerEntity.getName(), entity.getName()) == 0)
            {
                throw new CollidingNameException(this, containerEntity, entity, c);
            }
            /**
            * If there are conflicting names within the current container
            * (this takes precedence into account based on how `entities`
            * is generated)
            */
            else if (findPrecedence(c, entity.getName()) != entity)
            {
                throw new CollidingNameException(this, findPrecedence(c,
                        entity.getName()), entity, c);
            }
            /**
            * Otherwise this Entity is fine
            */
            else
            {
                string fullPath = resolver.generateName(modulle, entity);
                string containerNameFullPath = resolver.generateName(modulle, containerEntity);
                gprintln("Entity \"" ~ fullPath
                        ~ "\" is allowed to be defined within container \""
                        ~ containerNameFullPath ~ "\"");

                /**
                * Check if this Entity is a Container, if so, then
                * apply the same round of checks within it
                */
                Container possibleContainerEntity = cast(Container) entity;
                if (possibleContainerEntity)
                {
                    checkContainerCollision(possibleContainerEntity);
                }
            }
        }

    }


    /**
    * TODO: Create a version of the below function that possibly
    * returns the list of Statement[]s ordered like below but
    * via a weighting system rather
    */
    public Statement[] getContainerMembers_W(Container c)
    {
        /* Statements */
        Statement[] statements;

        /* TODO: Implement me */

        return statements;
    }

    /**
    * Returns container members in order of
    * Clazz, Function, Variable
    */
    private Entity[] getContainerMembers(Container c)
    {
        /* Entities */
        Entity[] entities;

        /* Get all classes */
        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Entity) statement)
            {
                entities ~= cast(Entity) statement;
            }
        }

        // /* Get all classes */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Clazz) statement)
        //     {
        //         entities ~= cast(Clazz) statement;
        //     }
        // }

        // /* Get all functions */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Function) statement)
        //     {
        //         entities ~= cast(Function) statement;
        //     }
        // }

        // /* Get all variables */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Variable) statement)
        //     {
        //         entities ~= cast(Variable) statement;
        //     }
        // }

        return entities;

    }

    /**
    * Finds the first occurring Entity with the provided
    * name based on Classes being searched, then Functions
    * and lastly Variables
    */
    public Entity findPrecedence(Container c, string name)
    {
        foreach (Entity entity; getContainerMembers(c))
        {
            /* If we find matching entity names */
            if (cmp(entity.getName(), name) == 0)
            {
                return entity;
            }
        }

        return null;
    }

    /**
    * Starting from a Container c this makes sure
    * that all classes defined within that container
    * do no clash name wise
    *
    * Make this general, so it checks all Entoties
    * within container, starting first with classes
    * then it should probably mark them, this will
    * be so we can then loop through all entities
    * including classes, of container c and for
    * every entity we come across in c we make
    * sure it doesn't have a name of something that 
    * is marked
    */
    private void checkClassNames(Container c)
    {
        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity)c;
        assert(containerEntity);

        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classTypes ~= cast(Clazz) statement;
            }
        }

        /* Declare each type */
        foreach (Clazz clazz; classTypes)
        {
            // gprintln("Name: "~resolver.generateName(modulle, clazz));
            /**
            * Check if the first class found with my name is the one being
            * processed, if so then it is fine, if not then error, it has
            * been used (that identifier) already
            *
            * TODO: We cann add a check here to not allow containerName == clazz
            * TODO: Call resolveUp as we can then stop class1.class1.class1
            * Okay top would resolve first part but class1.class2.class1
            * would not be caught by that
            *
            * TODO: This will meet inner clazz1 first, we need to do another check
            */
            if (resolver.resolveUp(c, clazz.getName()) != clazz)
            {
                Parser.expect("Cannot define class \"" ~ resolver.generateName(modulle,
                        clazz) ~ "\" as one with same name, \"" ~ resolver.generateName(modulle,
                        resolver.resolveUp(c, clazz.getName())) ~ "\" exists in container \"" ~ resolver.generateName(
                        modulle, containerEntity) ~ "\"");
            }
            else
            {
                /* Get the current container's parent container */
                Container parentContainer = containerEntity.parentOf();

                /* Don't allow a class to be named after it's container */
                // if(!parentContainer)
                // {
                if (cmp(containerEntity.getName(), clazz.getName()) == 0)
                {
                    Parser.expect("Class \"" ~ resolver.generateName(modulle,
                            clazz) ~ "\" cannot be defined within container with same name, \"" ~ resolver.generateName(
                            modulle, containerEntity) ~ "\"");
                }

                /* TODO: Loop througn Container ENtitys here */
                /* Make sure that when we call findPrecedence(entity) == current entity */

                // }

                /* TODO: We allow shaddowing so below is disabled */
                /* TODO: We should however use the below for dot-less resolution */
                // /* Find the name starting in upper cotainer */
                // Entity clazzAbove = resolveUp(parentContainer, clazz.getName());

                // if(!clazzAbove)
                // {

                // }
                // else
                // {
                //     Parser.expect("Name in use abpve us, bad"~to!(string)(clazz));
                // }

                /* If the Container's parent container is Module then we can have
                /* TODO: Check that it doesn;t equal any class up the chain */
                /* TODO: Exclude Module from this */

                // /* Still check if there is something with our name above us */
                // Container parentContainer = c.parentOf();

                // /* If at this level container we find duplicate */
                // if(resolveUp(parentContainer, clazz.getName()))
                // {

                //         Parser.expect("Class with name "~clazz.getName()~" defined in class "~c.getName());

                // }

            }
        }

        /**
        * TODO: Now we should loop through each class and do the same
        * so we have all types defined
        */
        //gprintln("Defined classes: "~to!(string)(Program.getAllOf(new Clazz(""), cast(Statement[])marked)));

        /**
        * By now we have confirmed that within the current container
        * there are no classes defined with the same name
        *
        * We now check each Class recursively, once we are done
        * we mark the class entity as "ready" (may be referenced)
        */
        foreach (Clazz clazz; classTypes)
        {
            gprintln("Check recursive " ~ to!(string)(clazz), DebugType.WARNING);

            /* Check the current class's types within */
            checkClassNames(clazz);

            // checkClassInherit(clazz);
        }

        /*Now we should loop through each class */
        /* Once outerly everything is defined we can then handle class inheritance names */
        /* We can also then handle refereces between classes */

        // gprintln("checkTypes: ")

    }

    /* Test name resolution */
    unittest
    {
        //assert()
    }

}

/* Test name colliding with container name (1/3) [module] */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/collide_container_module1.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
    Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.y");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member y.y collided with root container (module) y */
        assert(e.defined == container);
    }
}



/* Test name colliding with container name (2/3) [module, nested collider] */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/collide_container_module2.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
    Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.a.b.c.y");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member y.a.b.c.y collided with root container (module) y */
        assert(e.defined == container);
    }
}

/* Test name colliding with container name (3/3) [container (non-module), nested collider] */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/collide_container_non_module.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b.c");
    Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b.c.c");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member a.b.c.c collided with a.b.c container */
        assert(e.defined == container);
    }
}

/* Test name colliding with member */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/collide_member.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity memberFirst = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member a.b.c.c collided with a.b.c container */
        assert(e.attempted != memberFirst);
    }
}

/* Test name colliding with member (check that the member defined is class (precendence test)) */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/precedence_collision_test.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity ourClassA = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member attempted was Variable and defined was Clazz */
        assert(cast(Variable)e.attempted);
        assert(cast(Clazz)e.defined);
    }
}


/* Test name colliding with container name (1/2) */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/collide_container.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Setup testing variables */
    Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
    Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.y");

    try
    {
        /* Perform test */
        typeChecker.beginCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        /* Make sure the member y.y collided with root container (module) y */
        assert(e.defined == container);
    }
}

/* Test name colliding with container name (1/2) */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/typecheck/simple_dependence_correct7.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

    /* Perform test */
    typeChecker.beginCheck();

    /* TODO: Insert checks here */
}



/** 
 * Code generation and typechecking
 *
 * Testing file: `simple_function_call.t`
 */
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    string sourceFile = "source/tlang/testing/typecheck/simple_function_call.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();

    Parser parser = new Parser(currentLexer.getTokens());
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

   

    /* Perform test */
    typeChecker.beginCheck();

    /* TODO: Actually test generated code queue */
}