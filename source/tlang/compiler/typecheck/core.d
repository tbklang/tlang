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
        import compiler.typecheck.dependency.core;

        // DNodeGenerator.staticTC = this;

        DNodeGenerator dNodeGenerator = new DNodeGenerator(this);
        DNode rootNode = dNodeGenerator.generate(); /* TODO: This should make it acyclic */

        /* Print the tree */
        string tree = rootNode.print();
        gprintln(tree);



        /* Grab functionData ??? */
        FunctionData[string] functions = grabFunctionDefs();
        gprintln("Defined functions: "~to!(string)(functions));
        /* TODO: Disable, this is just to peep */
        foreach(FunctionData funcData; functions.values)
        {
            DNode funcNode = funcData.generate();
            gprintln(funcNode.print());
        }

        /* TODO: Work in progress (NEW!!!) */
        /* Get the action-list (linearised bottom up graph) */
        DNode[] actionList = rootNode.poes;
        doTypeCheck(actionList);

        
        printTypeQueue();
        


        /**
        * TODO: What's next?
        *
        * 1. Fetch the tree from the DNodeGenerator
        */

        
    }

    import compiler.typecheck.dependency.core;
    import std.container.slist;

    import compiler.codegen.instruction;
    private SList!(Instruction) codeQueue;

    public void addInstr(Instruction inst)
    {
        codeQueue.insert(inst);
    }

    public void addInstrB(Instruction inst)
    {
        codeQueue.insertAfter(codeQueue[], inst);
    }

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

    public bool isInstrEmpty()
    {
        return codeQueue.empty;
    }
    
    public SList!(Instruction) getCodeQueue()
    {
        return codeQueue;
    }

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
                * TODO: Find the type of literal. Integer v.s. floating point
                */
                NumberLiteral numLit = cast(NumberLiteral)statement;
                import std.string : indexOf;
                bool isFloat = indexOf(numLit.getNumber(), ".") > -1; 
                gprintln("NUMBER LIT: isFloat: "~to!(string)(isFloat));
                addType(getType(modulle, isFloat ? "float" : "int"));

                /**
                * Codegen
                *
                * FIXME: Add support for floats
                * TODO: We just assume (for integers) byte size 4?
                */
                Value valInstr;

                if(!isFloat)
                {
                    ulong i = to!(ulong)((cast(NumberLiteral)statement).getNumber());
                    LiteralValue litValInstr = new LiteralValue(i, 4);

                    valInstr = litValInstr;
                }
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
                auto gVar = cast(TypedEntity)resolver.resolveBest(g.getContext().getContainer(), g.getName());

                string variableName = resolver.generateName(modulle, gVar);

                gprintln("VarName: "~variableName);

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
                */
                FetchValueVar fVV = new FetchValueVar(variableName, 4);
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
                Variable[] paremeters = func.getParams();


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
                * 1. Create FUncCallInstr
                * 2. Evaluate args and process them?! wait done elsewhere yeah!!!
                * 3. Pop arts into here
                * 4. AddInstr(combining those args)
                * 5. DOne
                */
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

            /**
            * Codegen
            *
            * 1. Get the variable's name
            * 2. Pop Value-instruction
            * 3. Generate VarAssignInstruction with Value-instruction
            */
            Instruction valueInstr = popInstr();
            gprintln(valueInstr is null);/*TODO: FUnc calls not implemented? Then is null for simple_1.t */
            VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
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
            gprintln("HELLO NIGGA");
            string variableName = resolver.generateName(modulle, variablePNode);
            VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4);

            /* NEW CODE (9th November 2021) Set the context */
            varDecInstr.context = variablePNode.context;


            /* If it is a Module variable declaration */
            if(cast(Module)variablePNode.context.container)
            {
                /* Check if there is a VariableAssignmentInstruction */
                Instruction possibleInstr = popInstr();
                if(possibleInstr !is null)
                {
                    VariableAssignmentInstr varAssInstr = cast(VariableAssignmentInstr)possibleInstr;
                    if(varAssInstr)
                    {
                        /* Check if the assignment is to this variable */
                        if(cmp(varAssInstr.varName, variableName) == 0)
                        {
                            /* If so, re-order (VarDec then VarAssign) */
                            
                            addInstrB(varDecInstr);
                            addInstrB(varAssInstr);
                        }
                        else
                        {
                            /* If not, then no re-order */
                            addInstrB(varAssInstr);
                            addInstrB(varDecInstr);
                        }
                    }
                    else
                    {
                        /* Push it back if not a VariableAssignmentInstruction */
                        
                        addInstr(possibleInstr);
                        addInstrB(varDecInstr);
                        
                    }
                }
            }
            /* If it is a Class (static) variable declaration */
            else if(cast(Clazz)variablePNode.context.container)
            {
                /* TODO: Make sure this is correct */
                addInstr(varDecInstr);
                gprintln("Hello>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");

            }

            

            
        }
        /* TODO: Add class init */
        else if(cast(compiler.typecheck.dependency.classes.classStaticDep.ClassStaticNode)dnode)
        {
            Clazz clazzPNode = cast(Clazz)dnode.getEntity();
            string clazzName = resolver.generateName(modulle, clazzPNode);

            /* TODO: I am rushing so idk which quantum op to use */
            // addInstrB(new ClassStaticInitAllocate(clazzName));

            /**
            * Add the class allocator instruction
            */
            addInstrB(new ClassStaticInitAllocate(clazzName));

            SList!(Instruction) kept;

            /* TODO: We should pop till we can't and whilst related to us */
            while(!isInstrEmpty())
            {
                Instruction instr = popInstr();
                gprintln("Bruh"~to!(string)(instr));

                /* TODO: THis should never fail, we should ALWAYS have class-related things */
                VariableDeclaration varDecInstr = cast(compiler.codegen.instruction.VariableDeclaration)instr;
                
                /* If not VariableDeclaration push back and end */
                if(!varDecInstr)
                {
                    addInstr(varDecInstr);
                    break;
                }
                /* If, then make sure related to this class */
                else
                {
                    /* TODO: Fetch the variable's context */
                    Variable varDecPNode = cast(Variable)resolver.resolveBest(clazzPNode, varDecInstr.varName);
                    gprintln(varDecPNode);
                    gprintln(varDecInstr.varName);
    
                    /* If we cast'd successfully to a VariableDclaration then it must mean a Variable exists */
                    assert(varDecPNode);

                    /**
                    * The VariableDeclaration is only related to the class
                    * if it is a direct sibling of it (contained by it)
                    */
                    if(varDecPNode.context.container == clazzPNode)
                    {
                        /* TODO: Add the static variable declARATION INITIALIZATIONS HERE */
                        kept.insert(varDecInstr);
                    }
                    /**
                    * If not, then put it back where it was
                    * and end
                    */
                    else
                    {
                        addInstr(varDecInstr);
                        break;
                    }
                }
                // assert(varDecInstr);
                // assert()

                
                
            }

            
            
            /**
            * Add the collected instructions
            */
            foreach(Instruction instruction; kept)
            {
                addInstrB(instruction);
            }
        }
        /* It will pop a bunch of shiiit */
        /* TODO: ANy statement */
        else if(cast(compiler.typecheck.dependency.core.DNode)dnode)
        {
            /* TODO: Get the STatement */
            Statement statement = dnode.getEntity();

            gprintln("Poes vavavas");

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
                VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
                

                VariableAssignmentInstr vAInstr = new VariableAssignmentInstr(variableName, valueInstr);
                addInstrB(vAInstr);
            }
        }
        


    }

    
    private void doTypeCheck(DNode[] actionList)
    {
        /* Resource stack */
        SList!(DNode) resStack;

        /* Klaar list */
        /* TODO: Add */

        gprintln("Action list: "~to!(string)(actionList));
        foreach(DNode node; actionList)
        {
            gprintln("Process: "~to!(string)(node));

            /* Print the code queue each time */
            printCodeQueue();

            /**
            * Now depending on thr DNode type we should
            * place ambiguous intems on stack then
            * move on, let the next process then
            * pop the stack and then consume it
            * for checking (typewise we can get 
            * information out of it), then when
            * done we should probably pop-the other
            * guy off and push something that resembles
            * an emmitable onto an EmitStack
            */


            /* will.i.am is a literal cringe */
            typeCheckThing(node);

            // /* If ExpressionDNode then ambiguous */
            // if(cast(compiler.typecheck.expression.ExpressionDNode)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            // /* If compiler.typecheck.variables.VariableAssignmentNode then amb */
            // else if(cast(compiler.typecheck.variables.VariableAssignmentNode)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            // /* If compiler.typecheck.variables.VariableAssignmentStdAlone then amb */
            // else if(cast(compiler.typecheck.variables.VariableAssignmentStdAlone)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            /* Non-ambigous ModuleVarDev */
            // else if(cast(compiler.typecheck.variables.ModuleVariableDeclaration)node)
            // {
            //     /**
            //     * Codegen
            //     *
            //     * Emit a variable declaration instruction
            //     */
            //     Variable variablePNode = cast(Variable)node.getEntity();
            //     string variableName = resolver.generateName(modulle, variablePNode);
            //     VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4);

            //     /* Check if there is a VariableAssignmentInstruction */
            //     Instruction possibleInstr = popInstr();
            //     if(possibleInstr !is null)
            //     {
            //         VariableAssignmentInstr varAssInstr = cast(VariableAssignmentInstr)possibleInstr;
            //         if(varAssInstr)
            //         {
            //             /* Check if the assignment is to this variable */
            //             if(cmp(varAssInstr.varName, variableName) == 0)
            //             {
            //                 /* If so, re-order (VarDec then VarAssign) */
                            
            //                 addInstrB(varDecInstr);
            //                 addInstrB(varAssInstr);
            //             }
            //             else
            //             {
            //                 /* If not, then no re-order */
            //                 addInstrB(varAssInstr);
            //                 addInstrB(varDecInstr);
            //             }
            //         }
            //         else
            //         {
            //             /* Push it back if not a VariableAssignmentInstruction */
                        
            //             addInstr(possibleInstr);
            //             addInstrB(varDecInstr);
                        
            //         }
            //     }
                

                

                
            // }
            // /* TODO: Remove above smh lmao */
            // else
            // {
            //     typeCheckThing(node);
            // }

            /* TODO: typecheck(node) */
            /* TODO: emit(node) */
        }

        gprintln("<<<<< FINAL CODE QUEUE >>>>>");
        /* Print the code queue each time */
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