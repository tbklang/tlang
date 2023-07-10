module tlang.compiler.typecheck.core;

import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import std.conv : to, ConvException;
import std.string;
import std.stdio;
import gogga;
import tlang.compiler.parsing.core;
import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.exceptions;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.typecheck.dependency.core;
import tlang.compiler.codegen.instruction;
import std.container.slist;
import std.algorithm : reverse;
import tlang.compiler.typecheck.meta;
import tlang.compiler.configuration;

/**
* The Parser only makes sure syntax
* is adhered to (and, well, partially)
* as it would allow string+string
* for example
*
*/
public final class TypeChecker
{
    /** 
     * The compiler configuration
     */
    private CompilerConfiguration config;



    private Module modulle;

    /* The name resolver */
    private Resolver resolver;

    /** 
     * The meta-programming processor
     */
    private MetaProcessor meta;

    public Module getModule()
    {
        return modulle;
    }

    /** 
     * Constructs a new `TypeChecker` based on the provided `Module`
     * of which to typecheck its members and using the default
     * compiler configuration
     *
     * Params:
     *   modulle = the `Module` to check
     *   config = the `CompilerConfiguration` (default if not specified)
     */
    this(Module modulle, CompilerConfiguration config = CompilerConfiguration.defaultConfig())
    {
        this.modulle = modulle;
        this.config = config;

        this.resolver = new Resolver(this);
        this.meta = new MetaProcessor(this, true);
        
        /* TODO: Module check?!?!? */
    }

    /** 
     * Returns the compiler configuration
     *
     * Returns: the `CompilerConfguration`
     */
    public CompilerConfiguration getConfig()
    {
        return config;
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
        

        DNodeGenerator dNodeGenerator = new DNodeGenerator(this);

        /* Generate the dependency tree */
        DNode rootNode = dNodeGenerator.generate(); /* TODO: This should make it acyclic */

        /* Perform the linearization to the dependency tree */
        rootNode.performLinearization();

        /* Print the tree */
        string tree = rootNode.getTree();
        gprintln(tree);

        /* Get the action-list (linearised bottom up graph) */
        DNode[] actionList = rootNode.getLinearizedNodes();
        doTypeCheck(actionList);

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

        /* Grab functionData ??? */
        FunctionData[string] functionDefinitions = grabFunctionDefs();
        gprintln("Defined functions: "~to!(string)(functionDefinitions));

        foreach(FunctionData funcData; functionDefinitions.values)
        {
            assert(codeQueue.empty() == true);

            /* Generate the dependency tree */
            DNode funcNode = funcData.generate();
            
            /* Perform the linearization to the dependency tree */
            funcNode.performLinearization();

            /* Get the action-list (linearised bottom up graph) */
            DNode[] actionListFunc = funcNode.getLinearizedNodes();

            //TODO: Would this not mess with our queues?
            doTypeCheck(actionListFunc);
            gprintln(funcNode.getTree());

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

    /** 
     * 🧠️ Feature: Universal coercion and type enforcer
     *
     * This tests two DIFFERENT types to see if they are:
     * 
     * 1. The same type (and if not, don't attempt coercion)
     * 2. The same type (and if not, ATTEMPT coercion)
     */
    unittest
    {
        import tlang.compiler.symbols.typing.core;

        TypeChecker tc = new TypeChecker(null);

        /* To type is `t1` */
        Type t1 = getBuiltInType(tc, "uint");
        assert(t1);

        /* We will comapre `t2` to `t1` */
        Type t2 = getBuiltInType(tc, "ubyte");
        assert(t2);
        Value v2 = new LiteralValue("25", t2);
        
        // Ensure instruction v2's type is `ubyte`
        assert(tc.isSameType(t2, v2.getInstrType()));


        try
        {
            // Try type match them, if initially fails then try coercion
            // ... (This should FAIL due to type mismatch and coercion disallowed)
            tc.typeEnforce(t1, v2, v2, false);
            assert(false);
        }
        catch(TypeMismatchException mismatch)
        {
            Type expectedType = mismatch.getExpectedType();
            Type attemptedType = mismatch.getAttemptedType();
            assert(tc.isSameType(expectedType, getBuiltInType(tc, "uint")));
            assert(tc.isSameType(attemptedType, getBuiltInType(tc, "ubyte")));
        }



        // Try type match them, if initially fails then try coercion
        // ... (This should pass due to its coercibility)
        tc.typeEnforce(t1, v2, v2, true);

        // This should have updated `v2`'s type to type `t1`
        t2 = v2.getInstrType();
        assert(tc.isSameType(t1, t2));
    }

    /** 
     * 🧠️ Feature: Universal coercion and type enforcer
     *
     * This tests two EQUAL/SAME types to see if they are:
     * 
     * 1. The same type
     */
    unittest
    {
        import tlang.compiler.symbols.typing.core;

        TypeChecker tc = new TypeChecker(null);

        /* To type is `t1` */
        Type t1 = getBuiltInType(tc, "uint");
        assert(t1);

        /* We will comapre `t2` to `t1` */
        Type t2 = getBuiltInType(tc, "uint");
        assert(t2);
        Value v2 = new LiteralValue("25", t2);
        
        // Ensure instruction v2's type is `uint`
        assert(tc.isSameType(t2, v2.getInstrType()));


        // This should not fail (no coercion needed in either)
        tc.typeEnforce(t1, v2, v2, false);
        tc.typeEnforce(t1, v2, v2, true);
    }

    // FIXME: I should re-write the below. It is now incorrect
    // ... as I DO ALLOW coercion of non literal-based instructions
    // ... now - so it fails because it is using an older specification
    // ... of TLang
    // /** 
    //  * 🧠️ Feature: Universal coercion and type enforcer
    //  *
    //  * This tests a failing case (read for details)
    //  */
    // unittest
    // {
    //     /** 
    //      * Create a simple program with
    //      * a function that returns an uint
    //      * and a variable of type ubyte
    //      */
    //     Module testModule = new Module("myModule");
    //     TypeChecker tc = new TypeChecker(testModule);

    //     /* Add the variable */
    //     Variable myVar = new Variable("ubyte", "myVar");
    //     myVar.parentTo(testModule);
    //     testModule.addStatement(myVar);

    //     /* Add the function with a return expression */
    //     VariableExpression retExp = new VariableExpression("myVar");
    //     ReturnStmt retStmt = new ReturnStmt(retExp);
    //     Function myFunc = new Function("function", "uint", [retStmt], []);
    //     retStmt.parentTo(myFunc);
    //     testModule.addStatement(myFunc);
    //     myFunc.parentTo(testModule);


    //     /* Now let's play with this as if the code-queue processor was present */


    //     /* Create a variable fetch instruction for the `myVar` variable */
    //     Value varFetch = new FetchValueVar("myVar", 1);
    //     varFetch.setInstrType(tc.getType(testModule, myVar.getType()));
    
    //     /** 
    //      * Create a ReturnInstruction now based on `function`'s return type
    //      *
    //      * 1) The ay we did this when we only have the `ReturnStmt` on the code-queue
    //      * is by finding the ReturnStmt's parent (the Function) and getting its type.
    //      *
    //      * 2) We must now "pop" the `varFetch` instruction from the stack and compare types.
    //      *
    //      * 3) If the type enforcement is fine, then let's check that they are equal
    //      *
    //      */

    //     // 1)
    //     Function returnStmtContainer = cast(Function)retStmt.parentOf();
    //     Type funcReturnType = tc.getType(testModule, returnStmtContainer.getType());

    //     // 2) The enforcement will fail as coercion of non-literals is NOT allowed
    //     try
    //     {
    //         tc.typeEnforce(funcReturnType, varFetch, true);
    //         assert(false);
    //     }
    //     catch(CoercionException e)
    //     {
    //         assert(true);
    //     }
        

    //     // 3) The types should not be the same
    //     assert(!tc.isSameType(funcReturnType, varFetch.getInstrType()));
    // }

    /** 
     * 🧠️ Feature: Universal coercion and type enforcer
     *
     * This tests a passing case (read for details)
     */
    unittest
    {
        /** 
         * Create a simple program with
         * a function that returns an uint
         * and an expression of type ubyte
         */
        Module testModule = new Module("myModule");
        TypeChecker tc = new TypeChecker(testModule);


        /* Add the function with a return expression */
        NumberLiteral retExp = new IntegerLiteral("21", IntegerLiteralEncoding.UNSIGNED_INTEGER);
        ReturnStmt retStmt = new ReturnStmt(retExp);
        Function myFunc = new Function("function", "uint", [retStmt], []);
        retStmt.parentTo(myFunc);
        testModule.addStatement(myFunc);
        myFunc.parentTo(testModule);


        /* Now let's play with this as if the code-queue processor was present */


        /* Create a new LiteralValue instruction with our literal and of type `ubyte` */
        Type literalType = tc.getType(testModule, "ubyte");
        Value literalValue = new LiteralValue(retExp.getNumber(), literalType);
    
        /** 
         * Create a ReturnInstruction now based on `function`'s return type
         *
         * 1) The ay we did this when we only have the `ReturnStmt` on the code-queue
         * is by finding the ReturnStmt's parent (the Function) and getting its type.
         *
         * 2) We must now "pop" the `literalValue` instruction from the stack and compare types.
         *
         * 3) If the type enforcement is fine, then let's check that they are equal
         *
         */

        // 1)
        Function returnStmtContainer = cast(Function)retStmt.parentOf();
        Type funcReturnType = tc.getType(testModule, returnStmtContainer.getType());

        // 2)
        tc.typeEnforce(funcReturnType, literalValue, literalValue, true);

        // 3) 
        assert(tc.isSameType(funcReturnType, literalValue.getInstrType()));
    }

    /** 
     * For: 🧠️ Feature: Universal coercion
     *
     * Given a Type `t1` and a `Value`-based instruction, if the
     * type of the `Value`-based instruction is the same as that
     * of the provided type, `t1`, then the function returns cleanly
     * without throwing any exceptions and will not fill in the `ref`
     * argument.
     *
     * If the types do NOT match then and cerocion is disallowed then
     * an exception is thrown.
     * 
     * If the types do NOT match and coercion is allowed then coercion
     * is attempted. If coercion fails an exception is thrown, else
     * it will place a `CastedValueInstruction` into the memory referrred
     * to by the `ref` parameter. It is this instruction that will contain
     * the action to cast the instruction to the coerced type.
     *
     * In the case that coercion is disabled then mismatched types results
     * in false being returned.
     *
     * Params:
     *   t1 = To-type (will coerce towards if requested)
     *   v2 = the `Value`-instruction
     *   ref coerceInstruction = the place to store the `CastedValueInstruction` in if coercion succeeds
     *                          (this will just be `v2` itself if the types are the same exactly)
     *   allowCoercion = whether or not at attempt coercion on initial type mismatch (default: `false`)
     *
     * Throws:
     *   TypeMismatchException if coercion is disallowed and the types are not equal
     * Throws:
     *   CoercionException if the types were not equal to begin with, coercion was allowed
     * but failed to coerce
     */
    private void typeEnforce(Type t1, Value v2, ref Value coerceInstruction, bool allowCoercion = false)
    {
        /* Debugging */
        string dbgHeader = "typeEnforce(t1="~t1.toString()~", v2="~v2.toString()~", attemptCoerce="~to!(string)(allowCoercion)~"): ";
        gprintln(dbgHeader~"Entering");
        scope(exit)
        {
            gprintln(dbgHeader~"Leaving");
        }

        /* Extract the original types of `v2` */
        Type t2 = v2.getInstrType();
        

        /* Check if the types are equal */
        if(isSameType(t1, t2))
        {
            // Do nothing
        }
        /* If the types are NOT the same */
        else
        {
            /* If coercion is allowed */
            if(allowCoercion)
            {
                /* If coerion fails, it would throw an exception */
                CastedValueInstruction coerceCastInstr = attemptCoercion(t1, v2);
                coerceInstruction = coerceCastInstr;
            }
            /* If coercion is not allowed, then we failed */
            else
            {
                throw new TypeMismatchException(this, t1, t2);
            }
        }
    }

    /** 
     * Compares the two types for equality
     *
     * Params:
     *   type1 = the first type
     *   type2 = the second type
     *
     * Returns: true if the types are equal, false otherwise
     */
    private bool isSameType(Type type1, Type type2)
    {
        bool same = false;

        // NOTE: We compare actual types, then check which type
        // ... the order is important due to type hierachy

        /* Handling for pointers */
        if(typeid(type1) == typeid(type2) && cast(Pointer)type1 !is null)
        {
            Pointer p1 = cast(Pointer)type1, p2 = cast(Pointer)type2;

            /* Now check that both of their referred types are the same */
            return isSameType(p1.getReferredType(), p2.getReferredType());
        }
        /* Handling for Integers */
        else if(typeid(type1) == typeid(type2) && cast(Integer)type1 !is null)
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
        /* Handling for all other cases */
        else if(typeid(type1) == typeid(type2))
        {
            return true;
        }

        gprintln("isSameType("~to!(string)(type1)~","~to!(string)(type2)~"): "~to!(string)(same), DebugType.ERROR);
        return same;
    }


    /** 
     * Given a type to try coerce towards and a literal value
     * instruction, this will check whether the literal itself
     * is within the range whereby it may be coerced
     *
     * Params:
     *   toType = the type to try coercing towards
     *   literalInstr = the literal to apply a range check to
     */
    private bool isCoercibleRange(Type toType, Value literalInstr)
    {
        // You should only be calling this on either a `LiteralValue`
        // ... or a `LiteralValueFloat` instruction
        // TODO: Add support for UnaryOpInstr (where the inner type is then)
        // ... one of the above
        assert(cast(LiteralValue)literalInstr || cast(LiteralValueFloat)literalInstr || cast(UnaryOpInstr)literalInstr);

        // LiteralValue (integer literal instructions)
        if(cast(LiteralValue)literalInstr)
        {
            LiteralValue integerLiteral = cast(LiteralValue)literalInstr;
            string literal = integerLiteral.getLiteralValue();

            // NOTE (X-platform): For cross-platform sake we should change the `ulong` to `size_t`
            ulong literalValue = to!(ulong)(literal);

            if(isSameType(toType, getType(null, "ubyte")))
            {
                if(literalValue >= 0 && literalValue <= 255)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            else if(isSameType(toType, getType(null, "ushort")))
            {
                if(literalValue >= 0 && literalValue <= 65_535)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            else if(isSameType(toType, getType(null, "uint")))
            {
                if(literalValue >= 0 && literalValue <= 4_294_967_295)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            else if(isSameType(toType, getType(null, "ulong")))
            {
                if(literalValue >= 0 && literalValue <= 18_446_744_073_709_551_615)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            // Handling for signed bytes [0, 127]
            else if(isSameType(toType, getType(null, "byte")))
            {
                if(literalValue >= 0 && literalValue <= 127)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            // Handling for signed shorts [0, 32_767]
            else if(isSameType(toType, getType(null, "short")))
            {
                if(literalValue >= 0 && literalValue <= 32_767)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            // Handling for signed integers [0, 2_147_483_647]
            else if(isSameType(toType, getType(null, "int")))
            {
                if(literalValue >= 0 && literalValue <= 2_147_483_647)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
            // Handling for signed longs [0, 9_223_372_036_854_775_807]
            else if(isSameType(toType, getType(null, "long")))
            {
                if(literalValue >= 0 && literalValue <= 9_223_372_036_854_775_807)
                {
                    // Valid coercion
                    return true;
                }
                else
                {
                    // Invalid coercion
                    return false;
                }
            }
        }
        // LiteralValue (integer literal instructions)
        else if(cast(LiteralValueFloat)literalInstr)
        {
            
        }
        // Unary operator
        else
        {
            UnaryOpInstr unaryOpLiteral = cast(UnaryOpInstr)literalInstr;
            assert(unaryOpLiteral.getOperator() == SymbolType.SUB);

            Value operandInstr = unaryOpLiteral.getOperand();

            // LiteralValue (integer literal instructions) with subtraction infront
            if(cast(LiteralValue)operandInstr)
            {
                LiteralValue theLiteral = cast(LiteralValue)operandInstr;

                // Then the actual literal will be `-<value>`
                string negativeLiteral = "-"~theLiteral.getLiteralValue();
                gprintln("Negated literal: "~negativeLiteral);

                // NOTE (X-platform): For cross-platform sake we should change the `long` to `ssize_t`
                long literalValue = to!(long)(negativeLiteral);

                if(isSameType(toType, getType(null, "byte")))
                {
                    if(literalValue >= -128 && literalValue <= 127)
                    {
                        // Valid coercion
                        return true;
                    }
                    else
                    {
                        // Invalid coercion
                        return false;
                    }
                }
                else if(isSameType(toType, getType(null, "short")))
                {
                    if(literalValue >= -32_768 && literalValue <= 32_767)
                    {
                        // Valid coercion
                        return true;
                    }
                    else
                    {
                        // Invalid coercion
                        return false;
                    }
                }
                else if(isSameType(toType, getType(null, "int")))
                {
                    if(literalValue >= -2_147_483_648 && literalValue <= 2_147_483_647)
                    {
                        // Valid coercion
                        return true;
                    }
                    else
                    {
                        // Invalid coercion
                        return false;
                    }
                }
                else if(isSameType(toType, getType(null, "long")))
                {
                    if(literalValue >= -9_223_372_036_854_775_808 && literalValue <= 9_223_372_036_854_775_807)
                    {
                        // Valid coercion
                        return true;
                    }
                    else
                    {
                        // Invalid coercion
                        return false;
                    }
                }
            }
            // LiteralValue (integer literal instructions) with subtraction infront
            else
            {

            }
        }


        return false;
    }


    /** 
     * Attempts to perform coercion of the provided Value-instruction
     * with respect to the provided to-type.
     * 
     * This should only be called if the types do not match.
     * 
     *
     * Params:
     *   toType = the type to attempt coercing the instruction to
     *   providedInstruction = instruction to coerce
     * Throws:
     *   CoercionException if we cannot coerce to the given to-type
     * Returns:
     *   the `CastedValueInstruction` on success
     */
    private CastedValueInstruction attemptCoercion(Type toType, Value providedInstruction)
    {
        gprintln("VibeCheck?");

        /* Extract the type of the provided instruction */
        Type providedType = providedInstruction.getInstrType();


        /** 
         * ==== Pointer coerion check first ====
         *
         * If the to-type is a Pointer
         * If the incoming provided-type is an Integer (non-pointer though)
         *
         * This is the case where an Integer [non-pointer though] (provided-type)
         * must be coerced to a Pointer (to-type)
         */
        if(isIntegralTypeButNotPointer(providedType) && isPointerType(toType))
        {
            // throw new CoercionException(this, toType, providedType, "Yolo baggins, we still need to implement dis");

            // Return a cast instruction to the to-type
            return new CastedValueInstruction(providedInstruction, toType);
        }
        // If it is a LiteralValue (integer literal) (support for issue #94)
        else if(cast(LiteralValue)providedInstruction)
        {
            // TODO: Add a check for if these types are both atleast integral (as in the Variable's type)
            // ... THEN (TODO): Check if range makes sense
            bool isIntegral = !(cast(Integer)toType is null); // Integrality check

            if(isIntegral)
            {
                bool isCoercible = isCoercibleRange(toType, providedInstruction); // TODO: Range check

                if(isCoercible)
                {
                    // TODO: Coerce here by changing the embedded instruction's type (I think this makes sense)
                    // ... as during code emit that is what will be hoisted out and checked regarding its type
                    // NOTE: Referrring to same type should not be a problem (see #96 Question 1)
                    // providedInstruction.setInstrType(toType);

                    // Return a cast instruction to the to-type
                    return new CastedValueInstruction(providedInstruction, toType);
                }
                else
                {
                    throw new CoercionException(this, toType, providedType, "Not coercible (range violation)");
                }
            }
            else
            {
                throw new CoercionException(this, toType, providedType, "Not coercible (lacking integral var type)");
            }
            
        }
        // If it is a LiteralValueFloat (support for issue #94)
        else if(cast(LiteralValueFloat)providedInstruction)
        {
            gprintln("Coercion not yet supported for floating point literals", DebugType.ERROR);
            assert(false);
        }
        // Unary operator (specifically with a minus)
        else if(cast(UnaryOpInstr)providedInstruction)
        {
            UnaryOpInstr unaryOpInstr = cast(UnaryOpInstr)providedInstruction;

            if(unaryOpInstr.getOperator() == SymbolType.SUB)
            {
                Value operandInstr = unaryOpInstr.getOperand();

                // If it is a negative LiteralValue (integer literal)
                if(cast(LiteralValue)operandInstr)
                {
                    bool isIntegral = !(cast(Integer)toType is null);

                    if(isIntegral)
                    {
                        LiteralValue literalValue = cast(LiteralValue)operandInstr;

                        

                        bool isCoercible = isCoercibleRange(toType, providedInstruction); // TODO: Range check

                        if(isCoercible)
                        {
                            // TODO: Coerce here by changing the embedded instruction's type (I think this makes sense)
                            // ... as during code emit that is what will be hoisted out and checked regarding its type
                            // NOTE: Referrring to same type should not be a problem (see #96 Question 1)
                            // providedInstruction.setInstrType(toType);

                            // Return a cast instruction to the to-type
                            return new CastedValueInstruction(providedInstruction, toType);
                        }
                        else
                        {
                            throw new CoercionException(this, toType, providedType, "Not coercible (range violation)");
                        }



                        // TODO: Implement things here
                        // gprintln("Please implement coercing checking for negative integer literals", DebugType.ERROR);
                        // assert(false);
                    }
                    else
                    {
                        gprintln("Yo, 'fix me', just throw an exception thing ain't integral, too lazy to write it now", DebugType.ERROR);
                        assert(false);
                    }
                }
                // If it is a negative LiteralValueFloat (floating-point literal)
                else if(cast(LiteralValueFloat)operandInstr)
                {
                    gprintln("Coercion not yet supported for floating point literals", DebugType.ERROR);
                    assert(false);
                }
                // If anything else is embedded
                else
                {
                    throw new CoercionException(this, toType, providedType, "Not coercible (lacking integral var type)");
                }
            }
            else
            {
                throw new CoercionException(this, toType, providedType, "Cannot coerce a non minus unary operation");
            }
        }
        /** 
         * If we arrive at this case then it is not any special literal
         * handling, rather we need to check promotion rules and on
         * cast-shortening - we raise an error
         */
        else
        {
            /** 
             * If the incoming type is `Number`
             * and the `toType` is `Number`
             */
            if(cast(Number)providedType && cast(Number)toType)
            {
                Number providedNumericType = cast(Number)providedType;
                Number toNumericType = cast(Number)toType;

                /**
                 * If the provided type is less than or equal
                 * in size to that of the to-type
                 */
                if(providedNumericType.getSize() <= toNumericType.getSize())
                {
                    // providedInstruction.setInstrType(toType);
                    // Return a cast instruction to the to-type
                    return new CastedValueInstruction(providedInstruction, toType);
                }
                /** 
                 * If the incoming type is bigger than the toType
                 *
                 * E.g.
                 * ```
                 * long i = 2;
                 * byte i1 = i;
                 * ```
                 */
                else
                {
                    throw new CoercionException(this, toType, providedType, "Loss of size would occur");
                }
            }
            else
            {
                gprintln("Mashallah why are we here? BECAUSE we should just use ze-value-based genral case!: "~providedInstruction.classinfo.toString());
                throw new CoercionException(this, toType, providedType);
            }
        }
    }

    /** 
     * Determines whether the provided Value-instruction refers
     * to a StackArray. This is used for array indexing checks,
     * to disambiguate between pointer-arrays and stack-based
     * arrays.
     *
     * Params:
     *   valInstr = the Value-based instruction to inspect
     * Returns: true if the FetchValInstr refers to a stack-array,
     * false otherwise
     */
    private bool isStackArrayIndex(Value valInstr)
    {
        // TODO: Rename
        Value indexToInstr = valInstr;

        /* We need a `FetchValueInstruction` as the first condition */
        FetchValueVar potFVV = cast(FetchValueVar)indexToInstr;
        if(potFVV)
        {
            /** 
                * Obtain the array variable being referred to
                * and obtain it's declared type
                */
            Context potFVVCtx = potFVV.getContext();
            Variable potStackArrVar = cast(Variable)resolver.resolveBest(potFVVCtx.getContainer(), potFVV.varName);
            Type variableDeclaredType = getType(potFVVCtx.getContainer(), potStackArrVar.getType());

            /**
            * If the type is `StackArray`
            */
            if(cast(StackArray)variableDeclaredType)
            {
                return true;
            }
        }

        return false;
    }

    /** 
     * Used to check if the type of the argument being passed into
     * a function call is a stack array and if the function's parameter
     * type is a pointer then this will check if the component type
     * of the stack array is the same as that of the pointer
     *
     * Params:
     *   parameterType = the function's parameter typoe
     *   argumentType = the argument's type
     *   outputType = variable to place updated type into
     *
     * Returns: true if the so, false otherwise
     */
    private bool canCoerceStackArray(Type parameterType, Type argumentType, ref Type outputType)
    {
        // If the argument being passed in is a stack array
        if(cast(StackArray)argumentType)
        {
            StackArray stackArrayType = cast(StackArray)argumentType;

            // Get the component type of the stack array
            Type stackArrCompType = stackArrayType.getComponentType();

            // Now check if the parameter is a pointer type
            if(cast(Pointer)parameterType)
            {
                Pointer parameterPointerCompType = cast(Pointer)parameterType;

                // Now create a new type for the stack array which is
                // effectively <stackArrayType>*
                Type stackArrayTypeCoerced = new Pointer(stackArrCompType);
                outputType = stackArrayTypeCoerced;

                // If the coerced stack array's component type is the same as the pointer's component type
                return isSameType(parameterPointerCompType, stackArrayTypeCoerced);
            }
            // If not, then return false immedtaiely
            else
            {
                return false;
            }
        }
        // If not, then immediately return false
        else
        {   
            return false;
        }
    }

    /**
     * Given two Value-based instructions this will firstly check if
     * at least one of the two is of type Pointer, then checks if the
     * remaining instruction is an of type Integer - the remaining instruction
     * will then be coerced into a pointer.
     *
     * If both are Pointers, neither are pointers or one or the other is
     * a Pointer and another is non-Integer then nothing will be coerced.
     * and this function is effectively a no-op.
     *
     * Params:
     *   vInstr1 = the first instruction
     *   vInstr2 = the second instruction
     */
    private void attemptPointerAriehmeticCoercion(Value vInstr1, Value vInstr2)
    {
        // Get the types of `vInstr1` and `vInstr2` respectively
        Type t1 = vInstr1.getInstrType();
        Type t2 = vInstr2.getInstrType();

        // TODO: Check if T1 is a pointer and then if T2 is an integer make it a pointer
        if(cast(Pointer)t1 && cast(Integer)t2)
        {
            Pointer t1Ptr = cast(Pointer)t1;

            Type coercedType = new Pointer(t1Ptr.getReferredType());
            vInstr2.setInstrType(coercedType);
        }
        // TODO: Else check if T2 is a pointer and then if T1 is an integer and make it a pointer
        else if(cast(Pointer)t2 && cast(Integer)t2)
        {
            Pointer t2Ptr = cast(Pointer)t2;

            Type coercedType = new Pointer(t2Ptr.getReferredType());
            vInstr1.setInstrType(coercedType);
        }
        else if(cast(Pointer)t1 && cast(Pointer)t2)
        {
            // Do nothing
            // TODO: Remove this branch
        }
        else
        {
            // Do nothing
        }
    }

    /** 
     * Checks if the given `Type` is a pointer-type
     *
     * Params:
     *   typeIn = the `Type` to check
     * Returns: `true` if the type is a `Pointer`,
     * `false` otherwise
     */
    private bool isPointerType(Type typeIn)
    {
        return typeid(typeIn) == typeid(Pointer);
    }

    /** 
     * Checks if the given `Type` is an integral type
     * (a kind-of `Integer`) HOWEVER that it is not
     * a `Pointer` (recall all ptrs are integers)
     *
     * Params:
     *   typeIn = the `Type` to check
     * Returns: `true` if integral (not pointer) type,
     * `false` otherwise
     */
    private bool isIntegralTypeButNotPointer(Type typeIn)
    {
        return cast(Integer)typeIn && !isPointerType(typeIn);
    }


    public void typeCheckThing(DNode dnode)
    {
        gprintln("typeCheckThing(): "~dnode.toString());

        /* ExpressionDNodes */
        if(cast(tlang.compiler.typecheck.dependency.expression.ExpressionDNode)dnode)
        {
            tlang.compiler.typecheck.dependency.expression.ExpressionDNode expDNode = cast(tlang.compiler.typecheck.dependency.expression.ExpressionDNode)dnode;

            Statement statement = expDNode.getEntity();
            gprintln("Hdfsfdjfds"~to!(string)(statement));

            /* Dependent on the type of Statement */

            if(cast(NumberLiteral)statement)
            {
                /**
                * Codegen
                *
                * TODO: We just assume (for integers) byte size 4?
                * 
                * Generate the correct value instruction depending
                * on the number literal's type
                */
                Value valInstr;

                /* Generate a LiteralValue (IntegerLiteral) */
                if(cast(IntegerLiteral)statement)
                {
                    IntegerLiteral integerLitreal = cast(IntegerLiteral)statement;

                    /**
                     * Determine the type of this value instruction by finding
                     * the encoding of the integer literal (part of doing issue #94)
                     */
                    Type literalEncodingType;
                    if(integerLitreal.getEncoding() == IntegerLiteralEncoding.SIGNED_INTEGER)
                    {
                        literalEncodingType = getType(modulle, "int");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.UNSIGNED_INTEGER)
                    {
                        literalEncodingType = getType(modulle, "uint");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.SIGNED_LONG)
                    {
                        literalEncodingType = getType(modulle, "long");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.UNSIGNED_LONG)
                    {
                        literalEncodingType = getType(modulle, "ulong");
                    }
                    assert(literalEncodingType);

                    // TODO: Insert getEncoding stuff here
                    LiteralValue litValInstr = new LiteralValue(integerLitreal.getNumber(), literalEncodingType);

                    valInstr = litValInstr;

                    // TODO: Insert get encoding stuff here
                }
                /* Generate a LiteralValueFloat (FloatingLiteral) */
                else
                {
                    FloatingLiteral floatLiteral = cast(FloatingLiteral)statement;

                    gprintln("We haven't sorted ouyt literal encoding for floating onts yet (null below hey!)", DebugType.ERROR);
                    Type bruhType = null;
                    assert(bruhType);
                    
                    LiteralValueFloat litValInstr = new LiteralValueFloat(floatLiteral.getNumber(), bruhType);

                    valInstr = litValInstr;

                    // TODO: Insert get encoding stuff here
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
                gprintln("Please implement strings", DebugType.ERROR);
                // assert(false);
                // addType(getType(modulle, "char*"));
                
                // /**
                // * Add the instruction and pass the literal to it
                // */
                // StringExpression strExp = cast(StringExpression)statement;
                // string strLit = strExp.getStringLiteral();
                // gprintln("String literal: `"~strLit~"`");
                // StringLiteral strLitInstr = new StringLiteral(strLit);
                // addInstr(strLitInstr);

                // gprintln("Typecheck(): String literal processing... [done]");
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
                Type variableType = getType(gVar.getContext().getContainer(), gVar.getType());

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
                fVV.setContext(g.getContext());


                addInstr(fVV);

                /* The type of a FetchValueInstruction is the type of the variable being fetched */
                fVV.setInstrType(variableType);
            }
            // else if(cast()) !!!! Continue here 
            else if(cast(BinaryOperatorExpression)statement)
            {
                BinaryOperatorExpression binOpExp = cast(BinaryOperatorExpression)statement;
                SymbolType binOperator = binOpExp.getOperator();
            

                /**
                * Codegen/Type checking
                *
                * Retrieve the two Value Instructions
                *
                * They would be placed as if they were on stack
                * hence we need to burger-flip them around (swap)
                */
                Value vRhsInstr = cast(Value)popInstr();
                Value vLhsInstr = cast(Value)popInstr();

                /** 
                 * Attempt to coerce the types of both instructions if one is
                 * a pointer and another is an integer, else do nothing
                 */
                // attemptPointerAriehmeticCoercion(vLhsInstr, vRhsInstr);


                Type vRhsType = vRhsInstr.getInstrType();
                Type vLhsType = vLhsInstr.getInstrType();


                /** 
                 * ==== Pointer coercion ====
                 *
                 * We now need to determine if our bianry operation:
                 *
                 * `a + b`
                 *
                 * Is a case where `a` is a Pointer and `b` is an Integer
                 * OR if `a` is an Integer and `b` is a Pointer
                 * But exclusive OR wise
                 *
                 * And only THEN must we coerce-cast the non-pointer one
                 *
                 * Last case is if the above two are not true.
                 */
                // FIXME: I must disable the above attemptPointerCOercion else it won;t work
                if(isPointerType(vLhsType) && isIntegralTypeButNotPointer(vRhsType)) // <a> is Pointer, <b> is Integer
                {
                    // Coerce right-hand side towards left-hand side
                    typeEnforce(vLhsType, vRhsInstr, vRhsInstr, true);
                }
                else if(isIntegralTypeButNotPointer(vLhsType) && isPointerType(vRhsType)) // <a> is Integer, <b> is Pointer
                {
                    // Coerce the left-hand side towards the right-hand side
                    typeEnforce(vRhsType, vLhsInstr, vLhsInstr, true);
                }
                else
                {
                    // TODO: What would be the bets rule here?
                    // To coerce to the bigger type of the two? Yes, that would
                    // make sense. But we need a helper method todo that for us
                }


                

                /** 
                 * Note: I don't mind the above changing the type of the
                 * instruction as it isn't really a widening. However,
                 * actually we rpobably should as it may not be wide
                 * enough!
                 * Like `64-bit (int) + ptr`    | This is fine (just semantics)
                 * But  `32-bit (int) + ptr`    | This requires widening, never mind Pointer+Pointer compatibility
                 */


                /**
                * TODO
                * Types must either BE THE SAME or BE COMPATIBLE
                */
                Type chosenType;
                if(isSameType(vLhsType, vRhsType))
                {
                    /* Left type + Right type = left/right type (just use left - it doesn't matter) */
                    chosenType = vLhsType;
                }
                else
                {
                    throw new TypeMismatchException(this, vLhsType, vRhsType, "Binary operator expression requires both types be same");
                }
                
                BinOpInstr addInst = new BinOpInstr(vLhsInstr, vRhsInstr, binOperator);
                addInstr(addInst);

                /* Set the Value instruction's type */
                addInst.setInstrType(chosenType);
            }
            /* Unary operator expressions */
            else if(cast(UnaryOperatorExpression)statement)
            {
                UnaryOperatorExpression unaryOpExp = cast(UnaryOperatorExpression)statement;
                SymbolType unaryOperator = unaryOpExp.getOperator();
                
                /* The type of the eventual UnaryOpInstr */
                Type unaryOpType;
                

                /**
                * Typechecking (TODO)
                */
                Value expInstr = cast(Value)popInstr();
                Type expType = expInstr.getInstrType();

                /* TODO: Ad type check for operator */

                /* If the unary operation is an arithmetic one */
                if(unaryOperator == SymbolType.ADD || unaryOperator == SymbolType.SUB)
                {
                    /* TODO: I guess any type fr */

                    if(unaryOperator == SymbolType.SUB)
                    {
                        // TODO: Note below is a legitimately good question, given a type
                        // ... <valueType>, what does applying a `-` infront of it (`-<valueType>`)
                        // ... mean in terms of its type?
                        //
                        // ... Does it remain the same type? We ask because of literal encoding.
                        // ... I believe the best way forward would be specifically to handle
                        // ... cases where `cast(LiteralValue)expInstr` is true here - just
                        // ... as we had the special handling for it in `NumberLiteral` statements
                        // ... before.
                        if(cast(LiteralValue)expInstr)
                        {
                            LiteralValue literalValue = cast(LiteralValue)expInstr;
                            string literalValueStr = literalValue.getLiteralValue();
                            ulong literalValueNumber = to!(ulong)(literalValueStr); // TODO: Add a conv check for overflow

                            if(literalValueNumber >= 9_223_372_036_854_775_808)
                            {
                                // TODO: I don't think we are meant to be doing the below, atleast for coercive cases
                                // TODO: make this error nicer
                                // throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, "Cannot represent -"~literalValueStr~" as too big");
                            }
                            // TODO: Check case of literal being 9223372036854775808 or above
                            // ... and having a `-` infront of it, then disallow

                            // TODO: Remove the below (just for now)
                            unaryOpType = expType;
                        }
                        else
                        {
                            // Else just copy the tyoe of the expInstr over
                            unaryOpType = expType;
                        }
                    }
                    else
                    {
                        // Else just copy the tyoe of the expInstr over
                        unaryOpType = expType;
                    }
                }
                /* If pointer dereference */
                else if(unaryOperator == SymbolType.STAR)
                {
                    gprintln("Type popped: "~to!(string)(expType));

                    // Okay, so yes, we would pop `ptr`'s type as `int*` which is correct
                    // but now, we must a.) ensure that IS the case and b.)
                    // push the type of `<type>` with one star less on as we are derefrencing `ptr`
                    Type derefPointerType;
                    if(cast(Pointer)expType)
                    {
                        Pointer pointerType = cast(Pointer)expType;
                        
                        // Get the type being referred to
                        Type referredType = pointerType.getReferredType();

                        unaryOpType = referredType;
                    }
                    else
                    {
                        throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, "You cannot dereference a type that is not a pointer type!");
                    }
                }
                /* If pointer create `&` */
                else if(unaryOperator == SymbolType.AMPERSAND)
                {
                    /**
                    * If the type popped from the stack was `<type>` then push
                    * a new type onto the stack which is `<type>*`
                    */
                    Type ptrType = new Pointer(expType);
                    unaryOpType = ptrType;
                }
                /* This should never occur */
                else
                {
                    gprintln("UnaryOperatorExpression: This should NEVER happen: "~to!(string)(unaryOperator), DebugType.ERROR);
                    assert(false);
                }
                

             
                

                // TODO: For type checking and semantics we should be checking WHAT is being ampersanded
                // ... as in we should only be allowing Ident's to be ampersanded, not, for example, literals
                // ... such a check can be accomplished via runtime type information of the instruction above
                
                
                UnaryOpInstr addInst = new UnaryOpInstr(expInstr, unaryOperator);
                gprintln("Made unaryop instr: "~to!(string)(addInst));
                addInstr(addInst);

                addInst.setInstrType(unaryOpType);
            }
            /* Function calls */
            else if(cast(FunctionCall)statement)
            {
                // gprintln("FuncCall hehe (REMOVE AFTER DONE)");

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
                            Type argType = valueInstr.getInstrType();
                            // gprintln(argType);

                            Variable parameter = paremeters[parmCount];
                            // gprintln(parameter);
                            

                            Type parmType = getType(func.parentOf(), parameter.getType());
                            // gprintln("FuncCall(Actual): "~argType.getName());
                            // gprintln("FuncCall(Formal): "~parmType.getName());
                            // gprintln("FuncCall(Actual): "~valueInstr.toString());

                            /* Scratch type used only for stack-array coercion */
                            Type coercionScratchType;


                            /* Match up types */
                            //if(argType == parmType)
                            if(isSameType(argType, parmType))
                            {
                                gprintln("Match type");

                                /* Add the instruction into the FunctionCallInstr */
                                funcCallInstr.setEvalInstr(parmCount, valueInstr);
                                gprintln(funcCallInstr.getEvaluationInstructions());
                            }
                            /* Stack-array argument to pointer parameter coercion check */
                            else if(canCoerceStackArray(parmType, argType, coercionScratchType))
                            {
                                // TODO: Add stack coercion check here
                                gprintln("Stack-based array has been coerced for function call");

                                // Update the fetch-var instruction's type to the coerced 
                                // TODO: Should we have applied this technically earlier then fallen through to
                                // ... the branch above? That would have worked and been neater - we should do
                                // ... that to avoid duplicating any code
                                valueInstr.setInstrType(coercionScratchType);

                                /* Add the instruction into the FunctionCallInstr */
                                funcCallInstr.setEvalInstr(parmCount, valueInstr);
                                gprintln(funcCallInstr.getEvaluationInstructions());
                            }
                            else
                            {
                                printCodeQueue();
                                gprintln("Wrong actual argument type for function call", DebugType.ERROR);
                                gprintln("Cannot pass value of type '"~argType.getName()~"' to function accepting '"~parmType.getName()~"'", DebugType.ERROR);

                                throw new TypeMismatchException(this, parmType, argType, "The actual argument's type does not match that of the function's parameter type");
                            }

                            parmCount--;
                        }
                        else
                        {
                            // TODO: This should enver happen, see book and remove soon (see Cleanup: Remove any pushbacks #101)
                            /* Push it back */
                            addInstr(instr);
                            break;
                        }
                    }
                }

                
                
                

                /**
                * Codegen
                *
                * 1. Create FuncCallInstr
                * 2. Evaluate args and process them?! wait done elsewhere yeah!!!
                * 3. Pop args into here
                * 4. addInstr(combining those args)
                *   4.1. If this is a statement-level function then `addInstrB()` is used
                * 5. Done
                */
                funcCallInstr.setContext(funcCall.getContext());

                // If not a statement-level function call then it is an expression
                // ... and ought to be placed at the top of the stack for later consumption
                if(!funcCall.isStatementLevelFuncCall())
                {
                    addInstr(funcCallInstr);
                }
                // If this IS a statement-level function call then it is not meant
                // ... to be placed on the top of the stack as it won't be consumed later,
                // ... rather it is finalised and should be added to the back of the code queue
                else
                {
                    addInstrB(funcCallInstr);

                    // We also, for emitter, must transfer this flag over by
                    // ... marking this function call instruction as statement-level
                    funcCallInstr.markStatementLevel();
                }

                /* Set the Value instruction's type */
                Type funcCallInstrType = getType(func.parentOf(), func.getType());
                funcCallInstr.setInstrType(funcCallInstrType);
            }
            /* Type cast operator */
            else if(cast(CastedExpression)statement)
            {
                CastedExpression castedExpression = cast(CastedExpression)statement;
                gprintln("Context: "~to!(string)(castedExpression.context));
                gprintln("ParentOf: "~to!(string)(castedExpression.parentOf()));
                
                /* Extract the type that the cast is casting towards */
                Type castToType = getType(castedExpression.context.container, castedExpression.getToType());


                /**
                * Codegen
                *
                * 1. Pop off the current value instruction corresponding to the embedding
                * 2. Create a new CastedValueInstruction instruction
                * 3. Set the context
                * 4. Add to front of code queue
                */
                Value uncastedInstruction = cast(Value)popInstr();
                assert(uncastedInstruction);

                /* Extract the type of the expression being casted */
                Type typeBeingCasted = uncastedInstruction.getInstrType();
                gprintln("TypeCast [FromType: "~to!(string)(typeBeingCasted)~", ToType: "~to!(string)(castToType)~"]");
                

                printCodeQueue();

                // TODO: Remove the `castToType` argument, this should be solely based off of the `.type` (as set below)
                CastedValueInstruction castedValueInstruction = new CastedValueInstruction(uncastedInstruction, castToType);
                castedValueInstruction.setContext(castedExpression.context);

                addInstr(castedValueInstruction);

                /* The type of the cats expression is that of the type it casts to */
                castedValueInstruction.setInstrType(castToType);
            }
            /* ArrayIndex */
            else if(cast(ArrayIndex)statement)
            {
                ArrayIndex arrayIndex = cast(ArrayIndex)statement;
                Type accessType;

                /* Pop the thing being indexed (the indexTo expression) */
                Value indexToInstr = cast(Value)popInstr();
                Type indexToType = indexToInstr.getInstrType();
                assert(indexToType);
                gprintln("ArrayIndex: Type of `indexToInstr`: "~indexToType.toString());

                /* Pop the index instruction (the index expression) */
                Value indexInstr = cast(Value)popInstr();
                Type indexType = indexInstr.getInstrType();
                assert(indexType);


                // TODO: Type check here the `indexToInstr` ensure that it is an array
                // TODO: Type check the indexInstr and ensure it is an integral type (index can not be anything else)

                // TODO: We need iets different for stack-arrays here
                


                /* Final Instruction generated */
                Instruction generatedInstruction;


                // // TODO: We need to add a check here for if the `arrayRefInstruction` is a name
                // // ... and if so if its type is `StackArray`, else we will enter the wrong thing below

                // TODO: Look up based on the name of the `FetchValueInstruction` (so if it is)
                // ... AND if it refers to a stack array
                bool isStackArray = isStackArrayIndex(indexToInstr);
                gprintln("isStackArray (being indexed-on)?: "~to!(string)(isStackArray), DebugType.ERROR);


               
                // /* The type of what is being indexed on */
                // Type indexingOnType = arrayRefInstruction.getInstrType();
                // gprintln("Indexing-on type: "~indexingOnType.toString(), DebugType.WARNING);


                /* Stack-array type `<compnentType>[<size>]` */
                if(isStackArray)
                {
                    StackArray stackArray = cast(StackArray)indexToType;
                    accessType = stackArray.getComponentType();
                    gprintln("ArrayIndex: Stack-array access");


                    gprintln("<<<<<<<< STCK ARRAY INDEX CODE GEN >>>>>>>>", DebugType.ERROR);



                    /**
                    * Codegen and type checking
                    *
                    * 1. Set the type (TODO)
                    * 2. Set the context (TODO)
                    */
                    StackArrayIndexInstruction stackArrayIndexInstr = new StackArrayIndexInstruction(indexToInstr, indexInstr);
                    stackArrayIndexInstr.setInstrType(accessType);
                    stackArrayIndexInstr.setContext(arrayIndex.context);

                    gprintln("IndexTo: "~indexToInstr.toString(), DebugType.ERROR);
                    gprintln("Index: "~indexInstr.toString(), DebugType.ERROR);
                    gprintln("Stack ARray type: "~stackArray.getComponentType().toString(), DebugType.ERROR);

                    

                    // assert(false);
                    generatedInstruction = stackArrayIndexInstr;
                }
                /* Array type `<componentType>[]` */
                else if(cast(Pointer)indexToType)
                {
                    gprintln("ArrayIndex: Pointer access");

                    Pointer pointer = cast(Pointer)indexToType;
                    accessType = pointer.getReferredType();

                    /**
                    * Codegen and type checking
                    *
                    * 1. Embed the index instruction and indexed-to instruction
                    * 2. Set the type of this instruction to the type of the array's component type
                    * 3. (TODO) Set the context
                    */
                    ArrayIndexInstruction arrayIndexInstr = new ArrayIndexInstruction(indexToInstr, indexInstr);
                    arrayIndexInstr.setInstrType(accessType);

                    generatedInstruction = arrayIndexInstr;
                }
                else
                {
                    // TODO: Throw an error here
                    // throw new TypeMismatchException()
                    gprintln("Indexing to an entity other than a stack array or pointer!", DebugType.ERROR);
                    assert(false);
                }



                // TODO: context (arrayIndex)

                gprintln("ArrayIndex: [toInstr: "~indexToInstr.toString()~", indexInstr: "~indexInstr.toString()~"]");

                gprintln("Array index not yet supported", DebugType.ERROR);
                // assert(false);

                addInstr(generatedInstruction);
            }
            else
            {
                gprintln("This ain't it chief", DebugType.ERROR);
                assert(false);
            }
        }
        /* VariableAssigbmentDNode */
        else if(cast(tlang.compiler.typecheck.dependency.variables.VariableAssignmentNode)dnode)
        {
            import tlang.compiler.typecheck.dependency.variables;

            /* Get the variable's name */
            string variableName;
            VariableAssignmentNode varAssignDNode = cast(tlang.compiler.typecheck.dependency.variables.VariableAssignmentNode)dnode;
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
            Instruction instr = popInstr();
            assert(instr);
            Value valueInstr = cast(Value)instr;
            assert(valueInstr);
            gprintln("VaribleAssignmentNode(): Just popped off valInstr?: "~to!(string)(valueInstr), DebugType.WARNING);


            Type rightHandType = valueInstr.getInstrType();
            gprintln("RightHandType (assignment): "~to!(string)(rightHandType));

            

        
            gprintln(valueInstr is null);/*TODO: FUnc calls not implemented? Then is null for simple_1.t */
            VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
            varAssInstr.setContext(variableAssignmentContext);
            // NOTE: No need setting `varAssInstr.type` as the type if in `getEmbeddedInstruction().type`
            
            addInstr(varAssInstr);
        }
        /* TODO: Add support */
        /**
        * TODO: We need to emit different code dependeing on variable declaration TYPE
        * We could use context for this, ClassVariableDec vs ModuleVariableDec
        */
        else if(cast(tlang.compiler.typecheck.dependency.variables.StaticVariableDeclaration)dnode)
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
            

            Type variableDeclarationType = getType(variablePNode.context.container, variablePNode.getType());


            // Check if this variable declaration has an assignment attached
            Value assignmentInstr;
            if(variablePNode.getAssignment())
            {
                Instruction poppedInstr = popInstr();
                assert(poppedInstr);

                // Obtain the value instruction of the variable assignment
                // ... along with the assignment's type
                assignmentInstr = cast(Value)poppedInstr;
                assert(assignmentInstr);
                Type assignmentType = assignmentInstr.getInstrType();



                /** 
                 * Here we can call the `typeEnforce` with the popped
                 * `Value` instruction and the type to coerce to
                 * (our variable's type)
                 */
                typeEnforce(variableDeclarationType, assignmentInstr, assignmentInstr, true);
                assert(isSameType(variableDeclarationType, assignmentInstr.getInstrType())); // Sanity check


                // // TODO: We should add a typecheck here where we update the type of the valInstr if it is of
                // // ... type NumberLiteral and coerce it to the variable referred to by the VariableAssignment
                // // ... see issue #94 part on "Coercion"
                // // If the types match then everything is fine
                // if(isSameType(variableDeclarationType, assignmentType))
                // {
                //     gprintln("Variable's declared type ('"~to!(string)(variableDeclarationType)~"') matches that of assignment expression's type ('"~to!(string)(assignmentType)~"')");
                // }
                // // If the types do not match
                // else
                // {
                //     // Then attempt coercion
                //     attemptCoercion(variableDeclarationType, assignmentInstr);
                // }
            }

            /* Generate a variable declaration instruction and add it to the codequeue */
            VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4, variableDeclarationType, assignmentInstr);
            varDecInstr.setContext(variablePNode.context);
            addInstrB(varDecInstr);
        }
        /* TODO: Add class init, see #8 */
        else if(cast(tlang.compiler.typecheck.dependency.classes.classStaticDep.ClassStaticNode)dnode)
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
        else if(cast(tlang.compiler.typecheck.dependency.core.DNode)dnode)
        {
            /* TODO: Get the STatement */
            Statement statement = dnode.getEntity();

            gprintln("Generic DNode typecheck(): Begin (examine: "~to!(string)(dnode)~" )");


            /* VariableAssignmentStdAlone */
            if(cast(VariableAssignmentStdAlone)statement)
            {
                VariableAssignmentStdAlone vasa = cast(VariableAssignmentStdAlone)statement;
                string variableName = vasa.getVariableName();

                /* Extract information about the variable declaration of the avriable being assigned to */
                Context variableContext = vasa.getContext();
                Variable variable = cast(Variable)resolver.resolveBest(variableContext.container, variableName);
                Type variableDeclarationType = getType(variableContext.container, variable.getType());

                /**
                * Codegen
                *
                * 1. Get the variable's name
                * 2. Pop Value-instruction
                * 3. Generate VarAssignInstruction with Value-instruction
                */
                Instruction instr = popInstr();
                assert(instr);
                Value assignmentInstr = cast(Value)instr;
                assert(assignmentInstr);

                
                Type assignmentType = assignmentInstr.getInstrType();
                assert(assignmentType);


                /**
                 * Here we will do the enforcing of the types
                 *
                 * Will will allow coercion of the provided
                 * type (the value being assigned to our variable)
                 * to the to-type (our Variable's declared type)
                 */
                typeEnforce(variableDeclarationType, assignmentInstr, assignmentInstr, true);
                assert(isSameType(variableDeclarationType, assignmentInstr.getInstrType())); // Sanity check

                // if(isSameType(variableDeclarationType, assignmentType))
                // {
                //     gprintln("Variable's declared type ('"~to!(string)(variableDeclarationType)~"') matches that of assignment expression's type ('"~to!(string)(assignmentType)~"')");
                // }
                // // If the type's do not match
                // else
                // {
                //     // Then attempt coercion
                //     attemptCoercion(variableDeclarationType, assignmentInstr);
                // }

                /* Generate a variable assignment instruction and add it to the codequeue */
                VariableAssignmentInstr vAInstr = new VariableAssignmentInstr(variableName, assignmentInstr);
                vAInstr.setContext(vasa.getContext());
                addInstrB(vAInstr);
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
                returnInstr.setContext(returnStatement.getContext());
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
                ifStatementInstruction.setContext(ifStatement.getContext());
                addInstrB(ifStatementInstruction);

                gprintln("If!");
            }
            /**
            * While loop (WhileLoop)
            */
            else if(cast(WhileLoop)statement)
            {
                WhileLoop whileLoop = cast(WhileLoop)statement;

                // FIXME: Do-while loops are still being considered in terms of dependency construction
                if(whileLoop.isDoWhile)
                {
                    gprintln("Still looking at dependency construction in this thing (do while loops )");
                    assert(false);
                }

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
                whileLoopInstruction.setContext(whileLoop.getContext());
                addInstrB(whileLoopInstruction);
            }
            /**
            * For loop (ForLoop)
            */
            else if(cast(ForLoop)statement)
            {
                ForLoop forLoop = cast(ForLoop)statement;

                /* Pop-off the Value-instruction for the condition */
                Value valueInstrCondition = cast(Value)popInstr();
                assert(valueInstrCondition);

                /* Calculate the number of instructions representing the body to tailPopInstr() */
                ulong bodyTailPopNumber = forLoop.getBranch().getStatements().length;
                gprintln("bodyTailPopNumber: "~to!(string)(bodyTailPopNumber));

                /* Pop off the body instructions, then reverse final list */
                Instruction[] bodyInstructions;
                for(ulong idx = 0; idx < bodyTailPopNumber; idx++)
                {
                    bodyInstructions ~= tailPopInstr();
                }
                bodyInstructions = reverse(bodyInstructions);

                // Create a branch instruction coupling the condition instruction + body instructions (in corrected order)
                BranchInstruction branchInstr = new BranchInstruction(valueInstrCondition, bodyInstructions);


                /* If there is a pre-run instruction */
                Instruction preRunInstruction;
                if(forLoop.hasPreRunStatement())
                {
                    preRunInstruction = tailPopInstr();
                }

                /**
                * Code gen
                *
                * 1. Create the ForLoopInstruction containing the BranchInstruction and
                * preRunInstruction
                * 2. Set the context
                * 3. Add the instruction
                */
                ForLoopInstruction forLoopInstruction = new ForLoopInstruction(branchInstr, preRunInstruction);
                forLoopInstruction.setContext(forLoop.context);
                addInstrB(forLoopInstruction);
            }
            /* Branch */
            else if(cast(Branch)statement)
            {
                Branch branch = cast(Branch)statement;

                gprintln("Look at that y'all, cause this is it: "~to!(string)(branch));
            }
            /**
            * Dereferencing pointer assignment statement (PointerDereferenceAssignment)
            */
            else if(cast(PointerDereferenceAssignment)statement)
            {
                PointerDereferenceAssignment ptrDerefAss = cast(PointerDereferenceAssignment)statement;
                
                /* Pop off the pointer dereference expression instruction (LHS) */
                Value lhsPtrExprInstr = cast(Value)popInstr();
                assert(lhsPtrExprInstr);

                /* Pop off the assignment instruction (RHS expression) */
                Value rhsExprInstr = cast(Value)popInstr();
                assert(rhsExprInstr);

                /**
                * Code gen
                *
                * 1. Create the PointerDereferenceAssignmentInstruction containing the `lhsPtrExprInstr`
                * and `rhsExprInstr`. Also set the pointer depth.
                * 2. Set the context
                * 3. Add the instruction
                */
                PointerDereferenceAssignmentInstruction pointerDereferenceAssignmentInstruction = new PointerDereferenceAssignmentInstruction(lhsPtrExprInstr, rhsExprInstr, ptrDerefAss.getDerefCount());
                pointerDereferenceAssignmentInstruction.setContext(ptrDerefAss.context);
                addInstrB(pointerDereferenceAssignmentInstruction);
            }
            /**
            * Discard statement (DiscardStatement)
            */
            else if(cast(DiscardStatement)statement)
            {
                DiscardStatement discardStatement = cast(DiscardStatement)statement;

                /* Pop off a Value instruction */
                Value exprInstr = cast(Value)popInstr();
                assert(exprInstr);

                /**
                * Code gen
                *
                * 1. Create the DiscardInstruction containing the Value instruction
                * `exprInstr`
                * 2. Set the context
                * 3. Add the instruction
                */
                DiscardInstruction discardInstruction = new DiscardInstruction(exprInstr);
                discardInstruction.setContext(discardStatement.context);
                addInstrB(discardInstruction);
            }
            /**
            * Array assignments (ArrayAssignment)
            */
            else if(cast(ArrayAssignment)statement)
            {
                ArrayAssignment arrayAssignment = cast(ArrayAssignment)statement;

                gprintln("Note, dependency processing of ArrayAssignment is not yet implemented, recall seggy", DebugType.ERROR);
                printCodeQueue();

                // TODO: We need to implement this, what should we put here
                // ... we also should be setting the correct types if need be

                /**
                 * At this point the code queue top of stack should look like this
                 * (as a requirement for Array assignments) (top-to-bottom)
                 *
                 * 1. Index instruction
                 * 2. Array name instruction
                 * 3. Assigment expression instruction
                 */
                Value indexInstruction = cast(Value)popInstr();

                
                // FIXME: Actually this may not always be the case, the name fetching makes sense
                // ... for stack arrays but not pointer ones where the arrayRef may be generated
                // ... from something else.
                Value arrayRefInstruction = cast(Value)popInstr();
                Value assignmentInstr = cast(Value)popInstr();

                gprintln("indexInstruction: "~indexInstruction.toString(), DebugType.WARNING);
                gprintln("arrayRefInstruction: "~arrayRefInstruction.toString(), DebugType.WARNING);
                gprintln("assignmentInstr: "~assignmentInstr.toString(), DebugType.WARNING);


                /* Final Instruction generated */
                Instruction generatedInstruction;


                // TODO: We need to add a check here for if the `arrayRefInstruction` is a name
                // ... and if so if its type is `StackArray`, else we will enter the wrong thing below
                bool isStackArray = isStackArrayIndex(arrayRefInstruction);
                gprintln("isStackArray (being assigned to)?: "~to!(string)(isStackArray), DebugType.ERROR);


               
                /* The type of what is being indexed on */
                Type indexingOnType = arrayRefInstruction.getInstrType();
                gprintln("Indexing-on type: "~indexingOnType.toString(), DebugType.WARNING);
                gprintln("Indexing-on type: "~indexingOnType.classinfo.toString(), DebugType.WARNING);

                
                /* Stack-array type `<compnentType>[<size>]` */
                if(isStackArray)
                {
                    // TODO: Crashing here currently with `simple_stack_arrays2.t`
                    // gprint("arrayRefInstruction: ");
                    // gprintln(arrayRefInstruction);
    
                    // StackArrayIndexInstruction stackArrayIndex = cast(StackArrayIndexInstruction)arrayRefInstruction;
                    
                    FetchValueVar arrayFetch = cast(FetchValueVar)arrayRefInstruction;

                    /** 
                     * Hoist out the declared stack array variable
                     */
                    Context stackVarContext = arrayFetch.getContext();
                    assert(stackVarContext); //TODO: We must set the Context when we make the `StackArrayIndexInstruction`
                    
                    Variable arrayVariable = cast(Variable)resolver.resolveBest(stackVarContext.container, arrayFetch.varName);
                    Type arrayVariableDeclarationType = getType(stackVarContext.container, arrayVariable.getType());

                    gprintln("TODO: We are still working on generating an assignment instruction for assigning to stack arrays", DebugType.ERROR);
                    gprintln("TODO: Implement instruction generation for stack-based arrays", DebugType.ERROR);

                    // TODO: Use StackArrayIndexAssignmentInstruction
                    StackArrayIndexAssignmentInstruction stackAssignmentInstr = new StackArrayIndexAssignmentInstruction(arrayFetch.varName, indexInstruction, assignmentInstr);

                    // TODO: See issue on `Stack-array support` for what to do next
                    // assert(false);
                    generatedInstruction = stackAssignmentInstr;

                    // TODO: Set context
                    /* Set the context */
                    stackAssignmentInstr.setContext(arrayAssignment.getContext());


                    gprintln(">>>>> "~stackAssignmentInstr.toString());
                    gprintln("Assigning into this array: "~to!(string)(assignmentInstr));
                    // assert(false);
                }
                /* Array type `<componentType>[]` */
                else if(cast(Pointer)indexingOnType)
                {
                    // TODO: Update this and don't use pointer dereference assignment
                    /** 
                     * Create a new pointer dereference assignment instruction
                     *
                     * 1. The deref is level 1 (as array index == one `*`)
                     * 2. The left-hand side is to be `new ArrayIndexInstruction(arrayRefInstruction, indexInstruction)`
                     * 3. Assignment expression is to be `assignmentInstr`
                     */
                    // NOTE: We couple arrBasePtr+offset (index) using an ArrayIndexInstruction (optimization/code-reuse)
                    ArrayIndexInstruction arrIndex = new ArrayIndexInstruction(arrayRefInstruction, indexInstruction);
                    ArrayIndexAssignmentInstruction arrDerefAssInstr = new ArrayIndexAssignmentInstruction(arrIndex, assignmentInstr);

                    gprintln("TODO: Implement instruction generation for pointer-based arrays", DebugType.ERROR);
                    generatedInstruction = arrDerefAssInstr;
                    // assert(false);

                    // TODO: Set context
                }
                // TODO: handle this error (if even possible?)
                else
                {
                    assert(false);
                }

                assert(generatedInstruction !is null);

                /* Add the instruction */
                addInstrB(generatedInstruction);
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

    // TODO: What actually is the point of this? It literally generates a `Class[]`
    // ... and then tosses it after returning. (See issue "Dead code tracking" #83)
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
        /* Run the meta-processor on the AST tree (starting from the Module) */
        meta.process(modulle);

        /* Process all pseudo entities of the given module */
        processPseudoEntities(modulle);

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

    private void processPseudoEntities(Container c)
    {
        /* Collect all `extern` declarations */
        ExternStmt[] externDeclarations;
        foreach(Statement curStatement; c.getStatements())
        {
            if(cast(ExternStmt)curStatement)
            {
                externDeclarations ~= cast(ExternStmt)curStatement;
            }
        }

        // TODO: We could remove them from the container too, means less loops in dependency/core.d

        /* Add each Entity to the container */
        foreach(ExternStmt curExternStmt; externDeclarations)
        {
            SymbolType externType = curExternStmt.getExternType();
            string externalSymbolName = curExternStmt.getExternalName();
            Entity pseudoEntity = curExternStmt.getPseudoEntity();

            /* Set the embedded pseudo entity's parent to that of the container */
            pseudoEntity.parentTo(c);

            c.addStatements([pseudoEntity]);

            assert(this.getResolver().resolveBest(c, externalSymbolName));
        }


        
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


version(unittest)
{
    import std.file;
    import std.stdio;
    import tlang.compiler.lexer.core;
    import tlang.compiler.lexer.kinds.basic : BasicLexer;
    import tlang.compiler.parsing.core;
}

/* Test name colliding with container name (1/3) [module] */
unittest
{
    

    string sourceFile = "source/tlang/testing/collide_container_module1.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
    string sourceFile = "source/tlang/testing/collide_container_module2.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
    string sourceFile = "source/tlang/testing/collide_container_non_module.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
    string sourceFile = "source/tlang/testing/collide_member.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
    string sourceFile = "source/tlang/testing/precedence_collision_test.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
    string sourceFile = "source/tlang/testing/collide_container.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
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
// TODO: Re-enable this when we take a look at the `discards` - for now discards at module level are not allowed
// ... therefore this unittest fails - otherwise it would have normally passed
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/typecheck/simple_dependence_correct7.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Perform test */
//     typeChecker.beginCheck();

//     /* TODO: Insert checks here */
// }



/** 
 * Code generation and typechecking
 *
 * Testing file: `simple_function_call.t`
 */
unittest
{
    string sourceFile = "source/tlang/testing/typecheck/simple_function_call.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    (cast(BasicLexer)currentLexer).performLex();

    Parser parser = new Parser(currentLexer);
    Module modulle = parser.parse();
    TypeChecker typeChecker = new TypeChecker(modulle);

   

    /* Perform test */
    typeChecker.beginCheck();

    /* TODO: Actually test generated code queue */
}