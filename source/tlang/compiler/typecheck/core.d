module tlang.compiler.typecheck.core;

import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import std.conv : to, ConvException;
import std.string;
import std.stdio;
import tlang.misc.logging;
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
import tlang.compiler.core;
import tlang.compiler.typecheck.dependency.store.interfaces : IFuncDefStore;
import tlang.compiler.typecheck.dependency.store.impls : FuncDefStore;
import tlang.compiler.typecheck.dependency.pool.interfaces;
import tlang.compiler.typecheck.dependency.pool.impls;
import tlang.misc.utils : panic;
import tlang.compiler.typecheck.dependency.variables;
import niknaks.functional : Optional;

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
     * The compiler instance
     */
    private Compiler compiler;

    /** 
     * The compiler configuration
     */
    private CompilerConfiguration config;

    /** 
     * The container of the program
     */
    private Program program;

    /** 
     * The name resolver
     */
    private Resolver resolver;

    /** 
     * The meta-programming processor
     */
    private MetaProcessor meta;

    /** 
     * Constructs a new `TypeChecker` with the given
     * compiler instance
     *
     * Params:
     *   compiler = the `Compiler` instance
     */
    this(Compiler compiler)
    {
        this.compiler = compiler;
        this.config = compiler.getConfig();
        this.program = compiler.getProgram();

        this.resolver = new Resolver(program, this);
        this.meta = new MetaProcessor(this, true);
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
     * Returns the program instance
     *
     * Returns: the `Program`
     */
    public Program getProgram()
    {
        return this.program;
    }

    /** 
     * Crashes the type checker with an expectation message
     * by throwing a new `TypeCheckerException`.
     *
     * Params:
     *   message = the expectation message
     */
    public void expect(string message)
    {
        throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, message);
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
        // TODO: Ensure this is CORRECT! (MODMAN)
        /* Check declaration and definition types */
        foreach(Module curModule; this.program.getModules())
        {
            checkDefinitionTypes(curModule);
        }
        
        // TODO: Ensure this is CORRECT! (MODMAN)
        /* TODO: Implement me */
        foreach(Module curModule; this.program.getModules())
        {
            checkClassInherit(curModule);
        }

        /**
        * Dependency tree generation
        *
        * Currently this generates a dependency tree
        * just for the module, the tree must be run
        * through after wards to make it
        * non-cyclic
        *
        */

        /* Create the dependency generator */
        IPoolManager poolManager = new PoolManager();
        IFuncDefStore funcDefStore = new FuncDefStore(this, poolManager);
        DNodeGenerator dNodeGenerator = new DNodeGenerator(this, poolManager, funcDefStore);

        /* Generate the dependency tree */
        DNode rootNode = dNodeGenerator.generate(); /* TODO: This should make it acyclic */

        /** 
         * TODO: Because we get a `Program` DNode out
         * of this we should perform linearization on
         * each sub-node and then process those seperately
         */
        foreach(DNode modDep; rootNode.getDeps())
        {
            Module mod = cast(Module)modDep.getEntity();
            assert(mod);
            DEBUG(format("Dependency node entry point mod: %s", modDep));

            // Linearize this module's dependencies
            modDep.performLinearization();

            // Print the dep tree
            string modTree = modDep.getTree();
            DEBUG(format("\n%s", modTree));

            // Get the linerization
            DNode[] modActions = modDep.getLinearizedNodes();

            // Perform typecheck/codegen for this
            doTypeCheck(modActions);

            /** 
             * After having done the typecheck/codegen
             * there would be instructions in the
             * `codeQueue`. We must extract these
             * now, clear the `codeQueue` and save
             * the extracted stuff to something
             * which maps `Module -> Instruction[]`
             */
            scratchToModQueue(mod);
            assert(codeQueue.empty() == true);

            /**
             * We must now find the function
             * definitions that belong to this
             * `Module` and process those
             * by generating the dependencies
             * for them
             */
            FunctionData[string] modFuncDefs = funcDefStore.grabFunctionDefs(mod);
            DEBUG(format("Defined functions for module '%s': %s", mod, modFuncDefs));
            foreach(FunctionData curFD; modFuncDefs.values)
            {
                assert(codeQueue.empty() == true);

                /* Add an entry to the reference counting map */
                touch(curFD.func);

                /* Generate the dependency tree */
                DNode funcNode = curFD.generate();
                
                /* Perform the linearization to the dependency tree */
                funcNode.performLinearization();

                /* Get the action-list (linearised bottom up graph) */
                DNode[] actionListFunc = funcNode.getLinearizedNodes();

                //TODO: Would this not mess with our queues?
                doTypeCheck(actionListFunc);
                DEBUG(funcNode.getTree());

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
                 * Copy over the current function's
                 * instructions which make part of
                 * its definition, clear the scratchpad
                 * `codeQueue` and map to these
                 * instructions to the `ModuleQueue`
                 */
                funcScratchToModQueue(mod, curFD);
                assert(codeQueue.empty() == true);
            }

            /** 
             * Copy the `initQueue` instructions over
             * to the `ModuleQueue` for the current
             * module and clear the queue for the
             * next module round
             */
            initsScratchToModQueue(mod);
        }

        /* Collect statistics */
        doPostChecks();
    }

    /** 
     * These are just checks we run for the convenience
     * of the user. They do not manipulate anything but
     * rather provide statistics
     */
    private void doPostChecks()
    {
        /** 
         * Find the variables which were declared but never used
         */
        if(this.config.hasConfig("typecheck:warnUnusedVars") && this.config.getConfig("typecheck:warnUnusedVars").getBoolean())
        {
            Variable[] unusedVariables = getUnusedVariables();
            if(unusedVariables.length)
            {
                WARN("There are "~to!(string)(unusedVariables.length)~" unused variables");
                foreach(Variable unusedVariable; unusedVariables)
                {
                    // TODO: Get a nicer name, full path-based
                    WARN("Variable '"~to!(string)(unusedVariable.getName())~"' is declared but never used");
                }
            }
        }

        /** 
         * Find the functions which were declared but never used
         */
        if(this.config.hasConfig("typecheck:warnUnusedFuncs") && this.config.getConfig("typecheck:warnUnusedFuncs").getBoolean())
        {
            Function[] unusedFuncs = getUnusedFunctions();
            if(unusedFuncs.length)
            {
                WARN("There are "~to!(string)(unusedFuncs.length)~" unused functions");
                foreach(Function unusedFunc; unusedFuncs)
                {
                    // TODO: Get a nicer name, full path-based
                    WARN("Function '"~to!(string)(unusedFunc.getName())~"' is declared but never used");
                }
            }
        }
    }

    /** 
     * Associates various instruction
     * sets with a given `Module`
     */
    private struct ModuleQueue
    {
        private Module owner;
        private Instruction[] codeInstrs;
        private Instruction[][string] functionBodyCodeQueues;
        private Instruction[] initInstrs;

        this(Module owner)
        {
            this.owner = owner;
        }

        public void setCode(Instruction[] instructions)
        {
            this.codeInstrs = instructions;
        }

        public Instruction[] getCode()
        {
            return this.codeInstrs;
        }

        public void setFunctionDeclInstr(string functionName, Instruction[] bodyInstrs)
        {
            this.functionBodyCodeQueues[functionName] = bodyInstrs;
        }

        public Instruction[][string] getFunctionDefinitions()
        {
            return this.functionBodyCodeQueues;
        }

        public void setInit(Instruction[] instructions)
        {
            this.initInstrs = instructions;
        }

        public Instruction[] getInitInstrs()
        {
            return this.initInstrs;
        }
    }

    private ModuleQueue[Module] moduleQueues;

    /** 
     * Gets the `ModuleQueue*` for the given
     * `Module` and creates one if it does
     * not yet already exist
     *
     * Params:
     *   owner = the `Module`
     * Returns: a `ModuleQueue*`
     */
    private ModuleQueue* getModQueueFor(Module owner)
    {
        // Find entry
        ModuleQueue* modQ = owner in this.moduleQueues;

        // If not there, make it
        if(!modQ)
        {
            this.moduleQueues[owner] = ModuleQueue(owner);
            return getModQueueFor(owner);
        }

        return modQ;
    }

    /** 
     * Takes the current scratchpad `codeQueue`,
     * copies its instructions, clears it
     * and then creates a new `ModuleQueue`
     * entry for it and adds it to the
     * `moduleQueues` array
     *
     * Params:
     *   owner = the owner `Module` to
     * associat with the current code
     * queue
     */
    private void scratchToModQueue(Module owner)
    {
        // Extract a copy
        Instruction[] copyQueue;
        foreach(Instruction instr; this.codeQueue)
        {
            copyQueue ~= instr;
        }

        // Clear the scratchpad `codeQueue`
        this.codeQueue.clear();

        // Get the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        // Set the `code` instructions
        modQ.setCode(copyQueue);
    }

    private void funcScratchToModQueue(Module owner, FunctionData fd)
    {
        // Extract a copy
        Instruction[] copyQueue;
        foreach(Instruction instr; this.codeQueue)
        {
            copyQueue ~= instr;
            DEBUG(format("FuncDef (%s): Adding body instruction: %s", fd.getName(), instr));
        }

        // Clear the scratchpad `codeQueue`
        this.codeQueue.clear();

        // Get the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        // Set this function definition's instructions
        modQ.setFunctionDeclInstr(fd.getName(), copyQueue);
    }

    private void initsScratchToModQueue(Module owner)
    {
        // Extract a copy
        Instruction[] copyQueue;
        foreach(Instruction instr; this.initQueue)
        {
            copyQueue ~= instr;
        }

        // Clear the scratchpad `initQueue`
        this.initQueue.clear();

        // Get the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        // Set the `init` instructions
        modQ.setInit(copyQueue);
    }
    
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

    public Instruction[] getGlobalCodeQueue(Module owner)
    {
        // Find the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        return modQ.getCode();
    }

    public Instruction[][string] getFunctionBodyCodeQueues(Module owner)
    {
        // Find the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        return modQ.getFunctionDefinitions();
    }


    


    /* Main code queue (used for temporary passes) */
    private SList!(Instruction) codeQueue; //TODO: Rename to `currentCodeQueue`

    /* Initialization queue */
    private SList!(Instruction) initQueue;


    //TODO: CHange to oneshot in the function
    public Instruction[] getInitQueue(Module owner)
    {
        // Find the module queue
        ModuleQueue* modQ = getModQueueFor(owner);
        assert(modQ);

        return modQ.getInitInstrs();
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
            DEBUG("InitQueue: "~to!(string)(i+1)~"/"~to!(string)(walkLength(initQueue[]))~": "~instruction.toString());
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

    /*
    * Prints the current contents of the code-queue
    */
    public void printCodeQueue()
    {
        import std.range : walkLength;
        ulong i = 0;
        foreach(Instruction instruction; codeQueue)
        {
            DEBUG(to!(string)(i+1)~"/"~to!(string)(walkLength(codeQueue[]))~": "~instruction.toString());
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

        File dummyFile;
        Compiler dummyCompiler = new Compiler("", "legitidk.t", dummyFile);
        TypeChecker tc = new TypeChecker(dummyCompiler);

        /* To type is `t1` */
        Type t1 = getBuiltInType(tc, tc.getProgram(), "uint");
        assert(t1);

        /* We will comapre `t2` to `t1` */
        Type t2 = getBuiltInType(tc, tc.getProgram(), "ubyte");
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
            assert(tc.isSameType(expectedType, getBuiltInType(tc, tc.getProgram(), "uint")));
            assert(tc.isSameType(attemptedType, getBuiltInType(tc, tc.getProgram(), "ubyte")));
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

        File dummyFile;
        Compiler dummyCompiler = new Compiler("", "legitidk.t", dummyFile);
        TypeChecker tc = new TypeChecker(dummyCompiler);

        /* To type is `t1` */
        Type t1 = getBuiltInType(tc, tc.getProgram(), "uint");
        assert(t1);

        /* We will comapre `t2` to `t1` */
        Type t2 = getBuiltInType(tc, tc.getProgram(), "uint");
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
        File dummyFile;
        Compiler compiler = new Compiler("", "", dummyFile);

        Program program = new Program();
        Module testModule = new Module("myModule");
        program.addModule(testModule);
        compiler.setProgram(program);
        
        TypeChecker tc = new TypeChecker(compiler);


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
        DEBUG(dbgHeader~"Entering");
        scope(exit)
        {
            DEBUG(dbgHeader~"Leaving");
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

        ERROR("isSameType("~to!(string)(type1)~","~to!(string)(type2)~"): "~to!(string)(same));
        return same;
    }

    /** 
     * Checks if the provided type is
     * a number type
     *
     * Params:
     *   typeIn = the `Type` to test
     * Returns: `true` if so, `false`
     * otherwise
     */
    public static bool isNumberType(Type typeIn)
    {
        return cast(Number)typeIn !is null;
    }

    /** 
     * Checks if the provided type is
     * an integral type
     *
     * Params:
     *   typeIn = the `Type` to test
     * Returns: `true` if so, `false`
     * otherwise
     */
    public static bool isIntegralType(Type typeIn)
    {
        return cast(Integer)typeIn !is null;
    }

    /** 
     * Checks if the two types are STRICTLY
     * of the same object type
     *
     * Params:
     *   t1 = the first type
     *   t2 = the second type
     * Returns: `true` if both types have
     * the same RTTI typeid, `false` otherwise
     */
    public static bool isStrictlySameType(Type t1, Type t2)
    {
        return typeid(t1) == typeid(t2);
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
        import tlang.compiler.typecheck.literals.ranges;

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
                return literalValue >= 0 && literalValue <= UBYTE_UPPER;
            }
            else if(isSameType(toType, getType(null, "ushort")))
            {
                return literalValue >= 0 && literalValue <= USHORT_UPPER;
            }
            else if(isSameType(toType, getType(null, "uint")))
            {
                return literalValue >= 0 && literalValue <= UINT_UPPER;
            }
            else if(isSameType(toType, getType(null, "ulong")))
            {
                return literalValue >= 0 && literalValue <= ULONG_UPPER;
            }
            // Handling for signed bytes [0, 127]
            else if(isSameType(toType, getType(null, "byte")))
            {
                return literalValue >= 0 && literalValue <= BYTE_UPPER;
            }
            // Handling for signed shorts [0, 32_767]
            else if(isSameType(toType, getType(null, "short")))
            {
                return literalValue >= 0 && literalValue <= SHORT_UPPER;
            }
            // Handling for signed integers [0, 2_147_483_647]
            else if(isSameType(toType, getType(null, "int")))
            {
                return literalValue >= 0 && literalValue <= INT_UPPER;
            }
            // Handling for signed longs [0, 9_223_372_036_854_775_807]
            else if(isSameType(toType, getType(null, "long")))
            {
                return literalValue >= 0 && literalValue <= LONG_UPPER;
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
                DEBUG("Negated literal: "~negativeLiteral);

                // NOTE (X-platform): For cross-platform sake we should change the `long` to `ssize_t`
                long literalValue = to!(long)(negativeLiteral);

                if(isSameType(toType, getType(null, "byte")))
                {
                    return literalValue >= BYTE_LOWER && literalValue <= BYTE_UPPER;
                }
                else if(isSameType(toType, getType(null, "short")))
                {
                    return literalValue >= SHORT_LOWER && literalValue <= SHORT_UPPER;
                }
                else if(isSameType(toType, getType(null, "int")))
                {
                    return literalValue >= INT_LOWER && literalValue <= INT_UPPER;
                }
                else if(isSameType(toType, getType(null, "long")))
                {
                    return literalValue >= LONG_LOWER && literalValue <= LONG_UPPER;
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
     * Checks if the provided type refers to a `StackArray`
     *
     * Params:
     *   typeIn = the `Type` to test
     * Returns: `true` if it refers to a `StackArray`,
     * `false` otherwise
     */
    private bool isStackArrayType(Type typeIn)
    {
        return cast(StackArray)typeIn !is null;
    }

    /** 
     * Checks if the provided type is
     * an enumeration type
     *
     * Params:
     *   typeIn = the `Type` to test
     * Returns: `true` if so, `false`
     * otherwise
     */
    public static bool isEnumType(Type typeIn)
    {
        return cast(Enum)typeIn !is null;
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
        DEBUG("VibeCheck?");

        /* Extract the type of the provided instruction */
        Type providedType = providedInstruction.getInstrType();


        /**
         * ==== Stack-array to pointer coercion ====
         *
         * If the provided-type is a `StackArray`
         * and the to-type is a `Pointer`.
         *
         * if this is the case we must cast the `StackArray`
         * to a new `Pointer` type of its component type
         */
        if(isStackArrayType(providedType) && isPointerType(toType))
        {
            // Extract the pointer (to-type's)  referred type
            Pointer toTypePointer = cast(Pointer)toType;
            Type toTypeReferred = toTypePointer.getReferredType();

            // Extract the stack array's component type
            StackArray providedTypeStkArr = cast(StackArray)providedType;
            Type stackArrCompType = providedTypeStkArr.getComponentType();       

            // We still need the component type to match the to-type's referred type
            if(isSameType(stackArrCompType, toTypeReferred))
            {
                DEBUG("Stack-array ('"~providedInstruction.toString()~"' coercion from type '"~providedType.getName()~"' to type of '"~toType.getName()~"' allowed :)");

                // Return a cast instruction to the to-type
                return new CastedValueInstruction(providedInstruction, toType);
            }
            // If not, error, impossible to coerce
            else
            {
                throw new CoercionException(this, toType, providedType, "Cannot coerce a stack array with component type not matching the provided to-type of the pointer type trying to be coerced towards");
            } 
        }
        /** 
         * ==== Pointer coerion check first ====
         *
         * If the to-type is a Pointer
         * If the incoming provided-type is an Integer (non-pointer though)
         *
         * This is the case where an Integer [non-pointer though] (provided-type)
         * must be coerced to a Pointer (to-type)
         */
        else if(isIntegralTypeButNotPointer(providedType) && isPointerType(toType))
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
            ERROR("Coercion not yet supported for floating point literals");
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
                        ERROR("Yo, 'fix me', just throw an exception thing ain't integral, too lazy to write it now");
                        assert(false);
                    }
                }
                // If it is a negative LiteralValueFloat (floating-point literal)
                else if(cast(LiteralValueFloat)operandInstr)
                {
                    ERROR("Coercion not yet supported for floating point literals");
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
                 * Firstly, both must be strictly the same KIND of number
                 * type
                 */
                if(isStrictlySameType(toNumericType, providedNumericType))
                {
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
                // FIXME: Test this with float fromType and int toType (will need float fixed first)
                else
                {
                    // TODO: Throw a TypeMismatcherror rather?
                    throw new CoercionException(this, toType, providedType, "Incompatible types");
                }
            }
            // TODO: Still busy with this
            else if(isEnumType(providedType))
            {
                // TODO: Determine the enum type and and ee if it matches the number type
                Enum enum_t = cast(Enum)providedType;
                DEBUG("enum_t:", enum_t);

                import tlang.compiler.symbols.typing.enums : getEnumType;
                Type m_type = getEnumType(this, enum_t);
                DEBUG("enum member type:", m_type);

                DEBUG("toType:", toType);

                if(isIntegralType(toType) && isIntegralType(m_type) && isIntegralAssignableTo(cast(Integer)toType, cast(Integer)m_type))
                {
                    // Return a cast instruction to the to-type
                    return new CastedValueInstruction(providedInstruction, toType);
                }
                else
                {
                    throw new CoercionException(this, toType, providedType);
                }
            }
            else
            {
                ERROR("Mashallah why are we here? BECAUSE we should just use ze-value-based genral case!: "~providedInstruction.classinfo.toString());
                throw new CoercionException(this, toType, providedType);
            }
        }
    }

    public static bool isIntegralAssignableTo(Integer toType, Integer ofType)
    {
        return ofType.getSize() <= toType.getSize();
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
            Variable potStackArrVar = cast(Variable)resolver.resolveBest(potFVVCtx.getContainer(), potFVV.getTarget());
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
    public bool isPointerType(Type typeIn)
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
    public bool isIntegralTypeButNotPointer(Type typeIn)
    {
        return cast(Integer)typeIn && !isPointerType(typeIn);
    }


    /** 
     * Determines the biggest of the two `Integer`-based types
     * and returns that one.
     *
     * If neither is bigger than the other then the first is
     * returned.
     *
     * Please do not pass in `Pointer` types here - NOT the
     * intended usage (even though allowed).
     *
     * Params:
     *   integralType1 = the first `Integer`-based type to test
     *   integralType2 = the second `Integer`-based type to test
     * Returns: the biggest `Integer` type
     */
    private Integer biggerOfTheTwo(Integer integralType1, Integer integralType2)
    {
        // Sanity check, please don't pass Pointer types in here
        // as that isn't the intended usage
        assert(!isPointerType(integralType1) && !isPointerType(integralType2));

        if(integralType1.getSize() > integralType2.getSize())
        {
            return integralType1;
        }
        else if(integralType1.getSize() < integralType2.getSize())
        {
            return integralType2;
        }
        else
        {
            return integralType1;
        }
    }

    public struct ReportData
    {
        private Instruction i;
        this(Instruction i)
        {
            this.i = i;
        }

        public Instruction originInstruction()
        {
            return this.i;
        }
    }

    /** 
     * Represents out-of-band
     * assignment data
     */
    private struct AssignmentData
    {
        private Value toInstr;
        private Value ofInstr;

        public void reset()
        {
            this.toInstr = null;
            this.ofInstr = null;
        }

        public void dbg()
        {
            DEBUG
            (
                format
                (
                    `
                    AssignmentData:
                        toInstr: %s
                        ofInstr: %s
                    `,
                    this.toInstr,
                    this.ofInstr
                )
            );
        }

        // used for assertions
        public bool isComplete()
        {
            return !(this.toInstr is null) &&
                   !(this.ofInstr is null);
        }
    }

    private AssignmentData current_assData;

    /** 
     * Debug-dumps the current
     * assignment data
     */
    private void debug_assData()
    {
        current_assData.dbg();
    }

    /** 
     * Resets the assignment 
     * data
     */
    private void reset_assData()
    {
        current_assData.reset();
    }

    /** 
     * Sets the instruction which represents
     * the entity being assigned TO
     *
     * Params:
     *   toInstr = the `Value` instruction
     */
    private void setAssignment_to(Value toInstr)
    {
        current_assData.toInstr = toInstr;
    }

    /** 
     * Sets the instruction which reprents
     * the value being assigned
     *
     * Params:
     *   ofInstr = the `Value` instruction
     */
    private void setAssignment_of(Value ofInstr)
    {
        current_assData.ofInstr = ofInstr;
    }

    /** 
     * Returns the `Value` instruction
     * representing what is being assigned
     * to
     *
     * Returns: the `Value` instruction
     */
    private Value getAssignment_to()
    {
        assert(current_assData.isComplete()); // Sanity check
        return current_assData.toInstr;
    }

    /** 
     * Returns the `Value` instruction
     * representing what is being assigned
     * (the value/expression) itself
     *
     * Returns: the `Value` instruction
     */
    private Value getAssignment_of()
    {
        assert(current_assData.isComplete()); // Sanity check
        return current_assData.ofInstr;
    }

    // FIXME: Do we _really_ need this?
    // a simple boolean entry map would
    // have worked. We don't need this
    // complexity
    private struct EntityVisitNode
    {
        private TypedEntity te;
        private bool declared;

        private ReportData rd;
        private bool hasReportData;

        @disable
        this();

        this(TypedEntity te)
        {
            this.te = te;
            this.declared = false;
        }

        this(TypedEntity te, ReportData rd)
        {
            this(te);
            this.rd = rd;
        }

        public void markDeclared()
        {
            this.declared = true;
        }

        public bool isDeclared()
        {
            return this.declared;
        }

        public Optional!(ReportData) report()
        {
            Optional!(ReportData) rd_opt;

            if(this.hasReportData)
            {
                rd_opt = Optional!(ReportData)(this.rd);
            }

            return rd_opt;
        }
    }

    private EntityVisitNode[TypedEntity] decl_fstMap;

    private void clear_declMap()
    {
        this.decl_fstMap.empty();
        DEBUG("Cleared out decl_fstMap");
    }

    /** 
     * Marks the given entity as declared
     * and stores with it some auxillary
     * data for later reporting
     *
     * Params:
     *   te = the entity
     *   rd = the auxillary report data
     */
    private void declare(TypedEntity te, ReportData rd)
    {
        // Sanity check: You should never be calling
        // ... this for the same entity more than once
        assert((te in this.decl_fstMap) is null);

        // Insert node and mark as declared
        this.decl_fstMap[te] = EntityVisitNode(te, rd);
        this.decl_fstMap[te].markDeclared();
    }

    /** 
     * Checks if the given entity
     * has been marked as declared
     *
     * Params:
     *   te = the `TypedEntity` to
     * check
     * Returns: `true` if declared,
     * `false` otherwise
     */
    private bool isDeclared(TypedEntity te)
    {
        EntityVisitNode* evn_ptr = te in this.decl_fstMap;

        // If no entry is present then
        // it must be false. Also create
        // a new entry for later checks.
        if(evn_ptr is null)
        {
            this.decl_fstMap[te] = EntityVisitNode(te);
            return false;
        }

        return evn_ptr.isDeclared();
    }

    /** 
     * Given a typed entity this checks if
     * it has been marked as declared yet.
     * In the case whereby it has not, then
     * an exception will be thrown, else it
     * will no-op.
     *
     * It takes in auxillary report data
     * representing the calling context
     * such a check was requested from.
     *
     * Params:
     *   te = the `TypedEntity` to check
     *   rdCtx = the `ReportData` context
     */
    private void bail_IfNotDeclared
    (
        TypedEntity te,
        ReportData rdCtx
    )
    {
        if(!isDeclared(te))
        {
            string entityName = te.getName();
            DEBUG("te not declared: ", te);

            EntityVisitNode* ent_ptr = te in this.decl_fstMap;

            Instruction usageFromInstr = rdCtx.originInstruction();
            import tlang.compiler.codegen.render;
            string org_s = tryRender(usageFromInstr);
            DEBUG("Original instruction line: ", org_s);

            throw new TypeCheckerException
            (
                this,
                TypeCheckerException.TypecheckError.ENTITY_NOT_DECLARED,
                format
                (
                    "Usage of entity '%s' prior to declaration at %s ...",
                    entityName,
                    org_s
                )
            );
        }
        else
        {
            DEBUG("te declared: ", te);
        }
    }

    /** 
     * A proxy method which calls the
     * underlying `Resolver` method
     * `resolveBest` with the first
     * two provided arguments. If the
     * resolution succeeds then the
     * found entity is returned, else
     * an exception is thrown with
     * the erroneous name and also 
     * the auxillary calling context
     * from where the resolution was
     * requested.
     *
     * Params:
     *   targetName = the name to
     * resolve
     *   ctx = the `Container` context
     *   rd = the auxillary calling
     * context for reporting in the
     * case of an error
     */
    private Entity bail_resolveBest
    (
        string targetName,
        Container ctx,
        ReportData rd
    )
    {
        Entity ent = this.resolver.resolveBest(ctx, targetName);

        if(ent is null)
        {
            Instruction usageFromInstr = rd.originInstruction();
            import tlang.compiler.codegen.render;
            string org_s = tryRender(usageFromInstr);

            string errMsg;
            // If FetchValueVar
            if(cast(FetchValueVar)usageFromInstr)
            {
                errMsg = "Cannot reference entity named '%s' in %s as it does not exist";
            }
            // If FuncCallInstr
            else if(cast(FuncCallInstr)usageFromInstr)
            {
                errMsg = "Cannot call function named '%s' in %s as no such function exists";
            }

            // Sanity check: We should only be calling this for the above two use cases
            assert(errMsg.length != 0);

            throw new TypeCheckerException
            (
                this,
                TypeCheckerException.TypecheckError.ENTITY_NOT_FOUND,
                format
                (
                    errMsg,
                    targetName,
                    org_s
                )
            );
        }

        return ent;
    }

    /** 
     * Instruction context
     *
     * This provides helper
     * information
     */
    private struct InstrCtx
    {
        /** 
         * The container with which
         * the instruction being validated
         * is a member of
         */
        private Container memberOf;

        /** 
         * Sets the container part of the context
         *
         * Params:
         *   membersContainer = the container to
         * set
         */
        public void setContainer(Container membersContainer)
        {
            this.memberOf = membersContainer;
        }

        /** 
         * Returns an optional of the container
         *
         * Returns: An `Optional`
         */
        public Optional!(Container) getContainer()
        {
            return memberOf is null ? Optional!(Container)() : Optional!(Container)(memberOf);
        }
    }

    /** 
     * Used to know whether or not
     * an instruction was already
     * validated or not
     *
     * TODO: We could clear this
     * after each dep-gen code/gen
     * run
     */
    private bool[Instruction] validationMap;

    /** 
     * Checks if the given instruction
     * has been validated yet
     *
     * Params:
     *   instr = the `Instruction` to
     * check
     * Returns: `true` if it has been
     * validated, `false` otherwise
     */
    private bool isValidated(Instruction instr)
    {
        bool* flag = instr in this.validationMap;

        // If not present, add a `false` entry
        if(flag is null)
        {
            this.validationMap[instr] = false;
            return isValidated(instr);
        }

        return *flag;
    }

    /** 
     * Marks the given instruction
     * as validated
     *
     * Params:
     *   instr = the `Instruction`
     * to mark as validated
     */
    private void markAsValidated(Instruction instr)
    {
        if(isValidated(instr))
        {
            ERROR("Attempt to double validate instruction ", instr);
            assert(false);
        }

        this.validationMap[instr] = true;
    }

    /** 
     * Performs the partial filling of certain aspects
     * of the given instruction via the provided
     * context.
     *
     * This can vary from setting the correct type for
     * the instruction to performing further type
     * checking on the instruction.
     *
     * The reason this exists is that certain instructions
     * can only have such information determined (and thereafter
     * set) once certain context is provided - which normally
     * is only available in later instructions used
     * in tandum with the one provided here.
     *
     * Params:
     *   ctx = the `InstrCtx`
     *   inputInstr = the `Instruction` to validate
     */
    private void validate(InstrCtx ctx, Instruction inputInstr)
    {
        scope(exit)
        {
            DEBUG
            (
                format
                (
                    "Validation exiting (InstrCtx: %s, Instruction: %s)",
                    ctx,
                    inputInstr
                )
            );
        }

        // Skip instructions which are already validated
        if(isValidated(inputInstr))
        {
            WARN("Not validating '", inputInstr, "' as it is already validated");
            return;
        }

        Optional!(Container) cOpt = ctx.getContainer();
        DEBUG("getContainer()? present: ", cOpt.isPresent());

        if(cOpt.isPresent())
        {
            Container cntnr = cOpt.get();
            DEBUG("validate() cntnr: ", cntnr);
            
            // FuncCallInstr
            if(cast(FuncCallInstr)inputInstr)
            {
                FuncCallInstr fcInstr = cast(FuncCallInstr)inputInstr;

                // Resolve the Function and bail out if it does not exist
                Entity funcEnt = bail_resolveBest(fcInstr.getTarget(), cntnr, ReportData(fcInstr));
                Function func = cast(Function)funcEnt;

                // Is the target a function? If not, then error
                if(func is null)
                {
                    throw new TypeCheckerException
                    (
                        this,
                        TypeCheckerException.TypecheckError.GENERAL_ERROR,
                        format
                        (
                            "Cannot call entity named '%s' as it is not a function",
                            fcInstr.getTarget()
                        )
                    );
                }

                // Increase its "touch" count
                touch(func);

                DEBUG("fcInstr: ", fcInstr);
                DEBUG("fcInstr (target): ", fcInstr.getTarget());
                DEBUG("cntnr: ", cntnr);

                assert(func);
                VariableParameter[] paremeters = func.getParams();
                size_t arity = func.getArity();

                // Argument count
                size_t argCnt = fcInstr.getArgCount();
                Value[] arguments = fcInstr.getEvaluationInstructions();

                // Arity mismatch check
                if(arity != argCnt)
                {
                    throw new TypeCheckerException
                    (
                        this,
                        TypeCheckerException.TypecheckError.GENERAL_ERROR,
                        format
                        (
                            "Function '%s' expects %d arguments but %d were provided",
                            func.getName(),
                            arity,
                            argCnt
                        )
                    );
                }

                DEBUG(format("Function parameters: %s", paremeters));
                DEBUG(format("Function arguments: %s", arguments));
                
                // Type-check every argument against its
                // formal parameter counterpart and perform
                // type coercion whilst doing so
                for(size_t i = 0; i < arity; i++)
                {
                    // Current parameter
                    VariableParameter param = paremeters[i];
                    Type parmType = getType(cntnr, param.getType());

                    // Current argument
                    Value arg = arguments[i];

                    // Validate the current argument by using
                    // the context at the callsite (at the `FuncCallInstr`)
                    Context fCS_Ctx = fcInstr.getContext();
                    assert(fCS_Ctx);
                    DEBUG("About to validate argument ", arg, " with ctx: ", ctx);
                    validate(InstrCtx(fCS_Ctx.getContainer()), arg);

                    // Now get the current argument's type
                    Type argType = arg.getInstrType();
                    assert(argType);

                    

                    


                    /* Scratch type used only for stack-array coercion */
                    Type coercionScratchType;

                    /**
                     * We need to enforce the `valueInstr`'s' (the `Value`-based
                     * instruction being passed as an argument) type to be that
                     * of the `parmType` (the function's parameter type)
                     */
                    typeEnforce(parmType, arg, arg, true);


                    /**
                     * Refresh the `argType` as `valueInstr` may have been
                     * updated and we need the new type
                     */
                    argType = arg.getInstrType();
                    

                    // Sanity check
                    assert(isSameType(argType, parmType));


                    /** 
                     * The argument value instruction stored
                     * in `arg` MAY have changed. Therefore
                     * we must place it back into the function
                     * call instruction.
                     */
                    fcInstr.setEvalInstr(i, arg);
                }

                /* Set the instruction's type to that of the function's return type */
                Type funcCallInstrType = getType(cntnr, func.getType());
                fcInstr.setInstrType(funcCallInstrType);

                /* Mark as validated */
                markAsValidated(fcInstr);
            }
            // FetchValueVar
            else if(cast(FetchValueVar)inputInstr)
            {
                FetchValueVar fVV = cast(FetchValueVar)inputInstr;

                /* Resolve the target against the provided container context */
                string targetName = fVV.getTarget();
                DEBUG("FVV: targetName: ", targetName);
                DEBUG("cntnr: ", cntnr);
                assert(cntnr);

                // Lookup entity but bail if not found
                Entity gVar = bail_resolveBest(targetName, cntnr, ReportData(fVV));
                string variableName = resolver.generateName(this.program, gVar);

                /* Type determined for instruction */
                Type instrType;

                // If a module is being referred to
                if(cast(Module)gVar)
                {
                    instrType = getType(cntnr, "module");
                }
                // If it is some kind-of typed entity
                else if(cast(TypedEntity)gVar)
                {
                    TypedEntity typedEntity = cast(TypedEntity)gVar;
                    instrType = getType(cntnr, typedEntity.getType());

                    // Bail out if it was not yet declared
                    bail_IfNotDeclared(typedEntity, ReportData(fVV));

                    // If it is a variable increase its "touch" count
                    if(cast(Variable)typedEntity)
                    {
                        touch(cast(Variable)typedEntity);
                    }
                }
                //
                else
                {
                    panic(format("Please add support for VariableExpression typecheck/codegen for handling: %s", gVar.classinfo));
                }

                /* Set the type accordingly */
                fVV.setInstrType(instrType);

                /* Mark as validated */
                markAsValidated(fVV);
            }
            else
            {
                WARN
                (
                    format
                    (
                        "Container-based validation for '%s' ignored as no case handles it",
                        inputInstr
                    )
                );
            }
        }
    }
    
    /** 
     * Determines the `Type` that should be used
     * for the given integeral literal encoding
     *
     * Params:
     *   ile = the encoding
     * Returns: the `Type`
     */
    public Type determineLiteralEncodingType(IntegerLiteralEncoding ile)
    {
        Type literalEncodingType;
        if(ile == IntegerLiteralEncoding.SIGNED_INTEGER)
        {
            literalEncodingType = getType(this.program, "int");
        }
        else if(ile == IntegerLiteralEncoding.UNSIGNED_INTEGER)
        {
            literalEncodingType = getType(this.program, "uint");
        }
        else if(ile == IntegerLiteralEncoding.SIGNED_LONG)
        {
            literalEncodingType = getType(this.program, "long");
        }
        else if(ile == IntegerLiteralEncoding.UNSIGNED_LONG)
        {
            literalEncodingType = getType(this.program, "ulong");
        }
        else
        {
            ERROR("Developer error: Impossible to get here");
            assert(false);
        }
        
        return literalEncodingType;
    }

    public void typeCheckThing(DNode dnode)
    {
        DEBUG("typeCheckThing(): "~dnode.toString());

        /* ExpressionDNodes */
        if(cast(tlang.compiler.typecheck.dependency.expression.ExpressionDNode)dnode)
        {
            tlang.compiler.typecheck.dependency.expression.ExpressionDNode expDNode = cast(tlang.compiler.typecheck.dependency.expression.ExpressionDNode)dnode;

            Statement statement = expDNode.getEntity();
            DEBUG("Hdfsfdjfds"~to!(string)(statement));

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
                    IntegerLiteral integerLiteral = cast(IntegerLiteral)statement;

                    /**
                     * Determine the type of this value instruction by finding
                     * the encoding of the integer literal (part of doing issue #94)
                     */
                    Type literalEncodingType = determineLiteralEncodingType(integerLiteral.getEncoding());
                    assert(literalEncodingType);

                    LiteralValue litValInstr = new LiteralValue(integerLiteral.getNumber(), literalEncodingType);
                    valInstr = litValInstr;
                }
                /* Generate a LiteralValueFloat (FloatingLiteral) */
                else
                {
                    FloatingLiteral floatLiteral = cast(FloatingLiteral)statement;

                    ERROR("We haven't sorted ouyt literal encoding for floating onts yet (null below hey!)");
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
                DEBUG("Typecheck(): String literal processing...");

                /**
                * Add the char* type as string literals should be
                * interned
                */
                ERROR("Please implement strings");
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
                VariableExpression g  = cast(VariableExpression)statement;
                string targetName = g.getName();

                /**
                * Codegen
                *
                * 1. Generate the instruction
                * 2. Set the Context of it to where the VariableExpression occurred
                */
                FetchValueVar fVV = new FetchValueVar(targetName);
                fVV.setContext(g.getContext());

                /* Push instruction to top of stack */
                addInstr(fVV);
            }
            // else if(cast()) !!!! Continue here 
            else if(cast(BinaryOperatorExpression)statement)
            {
                BinaryOperatorExpression binOpExp = cast(BinaryOperatorExpression)statement;
                Context binOpCtx = binOpExp.getContext();
                assert(binOpCtx);
                SymbolType binOperator = binOpExp.getOperator();
                
                DEBUG("===========================================");
                DEBUG(format("BinaryOpExpression: %s", binOpExp));
                DEBUG("===========================================");
            

                /**
                * Codegen/Type checking
                *
                * Retrieve the two Value Instructions
                *
                * They would be placed as if they were on stack
                * hence we need to burger-flip them around (swap)
                */
                printCodeQueue();
                Value vRhsInstr = cast(Value)popInstr();
                Value vLhsInstr = cast(Value)popInstr();
                DEBUG("vLhsInstr: ", vLhsInstr);
                DEBUG("vRhsInstr: ", vRhsInstr);

                DEBUG("Sir shitsalot");

                if(binOperator == SymbolType.DOT)
                {
                    // panic("Implement dot operator typecheck/codegen");

                    DEBUG("Humburger");

                    // lhs=FetchValueVar rhs=<undetermined>
                    
                    if(cast(FetchValueVar)vLhsInstr)
                    {
                        FetchValueVar fetchValVarInstr = cast(FetchValueVar)vLhsInstr;
                        string targetName = fetchValVarInstr.getTarget();
                        DEBUG(format("targetName: %s", targetName));

                        Entity leftEntity = resolver.resolveBest(binOpCtx.getContainer(), targetName);
                        assert(leftEntity); // Should always be true because dependency generator catches bad names (non-existent)

                        Container containerLeft = cast(Container)leftEntity;

                        // TODO: Handle error message nicwer
                        if(!containerLeft)
                        {
                            throw new TypeCheckerException
                            (
                                this,
                                TypeCheckerException.TypecheckError.GENERAL_ERROR,
                                format
                                (
                                    "Left-hand operand of '%s' of (%s %s %s) refers to an entity which is not a container",
                                    vLhsInstr,
                                    vLhsInstr,
                                    binOperator,
                                    vRhsInstr
                                )
                            );
                        }
                        // Can't do `<functionName>.<member>`
                        else if(cast(Function)leftEntity)
                        {
                            import tlang.compiler.codegen.render : tryRender;
                            throw new TypeCheckerException
                            (
                                this,
                                TypeCheckerException.TypecheckError.GENERAL_ERROR,
                                format
                                (
                                    "Cannot apply the dot operator with left-hand operand '%s' which is a function's name in '%s.%s'",
                                    tryRender(vLhsInstr),
                                    tryRender(vLhsInstr),
                                    tryRender(vRhsInstr)
                                )
                            );
                        }
                        


                        // lhs=<name of Container>

                        // 

                        /** 
                         * rhs=FetchValueVar
                         *
                         * In this case we are trying
                         * to access a member inside
                         * our left-hand side. Therefore
                         * the resultant instruction
                         * should be to access that
                         * member field within that
                         * container
                         */
                        if(cast(FetchValueVar)vRhsInstr)
                        {
                            FetchValueVar fetchValVarRight = cast(FetchValueVar)vRhsInstr;

                            string member = fetchValVarRight.getTarget();
                            DEBUG("memba name", member);

                            // Ensure that there is an Entity named `member` within `containerLeft`
                            Entity memberEnt = resolver.resolveWithin(containerLeft, member);
                            
                            if(!memberEnt)
                            {
                                throw new TypeCheckerException
                                (
                                    this,
                                    TypeCheckerException.TypecheckError.GENERAL_ERROR,
                                    format
                                    (
                                        "No member named '%s' within container '%s'",
                                        member,
                                        containerLeft
                                    )
                                );
                            }

                            // If member is a container
                            if(cast(Container)memberEnt)
                            {
                                DEBUG("memberEnt is a container");

                                // Create a new FetchValueInstr
                                // which takes `<leftName>.<rightName>`
                                // and makes that the new name?
                                string newName = targetName~"."~member;
                                fetchValVarRight.setTarget(newName);

                                // Instruction type is a container type
                                fetchValVarRight.setInstrType(getType(this.program, "container"));

                                // Push back to top of stack
                                addInstr(fetchValVarRight);

                                return;
                            }

                            // If member is a variable
                            else if(cast(Variable)memberEnt)
                            {
                                DEBUG("memberEnt is a variable");

                                // Update the `FetchValueVar`'s name
                                // to be the full path `<targetName>.<member>`
                                string newName = targetName~"."~member;
                                fetchValVarRight.setTarget(newName);

                                // FIXME: Validation should set correct VarLen, actually
                                // the instr type dictates this, deprecate the VarLen in `FetchValueVar`

                                // Push the right hand side then
                                // BACK to the top of stack
                                addInstr(fetchValVarRight);

                                // Validate it with the container-left as context
                                validate(InstrCtx(containerLeft), fetchValVarRight);
                                assert(fetchValVarRight.getInstrType());

                                return;
                            }

                            panic("Implement");
                            // panic("yebo");
                        }
                        // rhs=FuncCallInstr
                        /**
                         * rhs=FuncCallInstr
                         *
                         * In this case simply place the
                         * function call instruction back
                         * onto the stack.
                         */
                        else if(cast(FuncCallInstr)vRhsInstr)
                        {
                            FuncCallInstr funcCallRight = cast(FuncCallInstr)vRhsInstr;
                            
                            // Validate the `FuncCallInstr` with the container to our left
                            validate(InstrCtx(containerLeft), funcCallRight);

                            // Push the function call instruction to the stack
                            addInstr(funcCallRight);

                            DEBUG("left: ", containerLeft);
                            DEBUG("right: ", funcCallRight, ", type: ", funcCallRight.getInstrType());

                            // Update target name to full name <leftContainer>.<ourName>
                            string newName = targetName~"."~funcCallRight.getTarget();
                            funcCallRight.setTarget(newName);

                            return;
                        }
                        else
                        {
                            panic("fok");
                        }
                    }
                    // lhs=Function rhs=Variable
                    else
                    {
                        panic(format("No handling for %s . %s yet", vLhsInstr, vRhsInstr));
                    }
                }
                
                /**
                 * Perform validation on both the left-hand side
                 * and right-hand side operands
                 */
                validate(InstrCtx(binOpCtx.getContainer()), vLhsInstr);
                validate(InstrCtx(binOpCtx.getContainer()), vRhsInstr);


                Type vRhsType = vRhsInstr.getInstrType();
                Type vLhsType = vLhsInstr.getInstrType();
                DEBUG("vLhsType: ", vLhsType);
                DEBUG("vRhsType: ", vRhsType);

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
                // If left and right operands are integral
                else if(isIntegralTypeButNotPointer(vLhsType) && isIntegralTypeButNotPointer(vRhsType))
                {
                    /**
                     * If one of the instructions if a `LiteralValue` (a numeric literal)
                     * and another is not then coerce the literal to the other instruction's
                     * type.
                     *
                     * If the above is NOT true then:
                     *
                     * Coerce the instruction which is the smaller of the two.
                     *
                     * If they are equal then:
                     *
                     *      If one is signed and the other unsigned then coerce
                     *      signed to unsigned
                     */
                    Integer vLhsTypeIntegral = cast(Integer)vLhsType;
                    assert(vLhsTypeIntegral);
                    Integer vRhsTypeIntegral = cast(Integer)vRhsType;
                    assert(vRhsTypeIntegral);

                    if(cast(LiteralValue)vLhsInstr || cast(LiteralValue)vRhsInstr)
                    {
                        // Type enforce left-hand instruction to right-hand instruction
                        if(cast(LiteralValue)vLhsInstr && cast(LiteralValue)vRhsInstr is null)
                        {
                            typeEnforce(vRhsTypeIntegral, vLhsInstr, vLhsInstr, true);
                        }
                        // Type enforce right-hand instruction to left-hand instruction
                        else if(cast(LiteralValue)vLhsInstr is null && cast(LiteralValue)vRhsInstr)
                        {
                            typeEnforce(vLhsTypeIntegral, vRhsInstr, vRhsInstr, true);
                        }
                        // Both are literal values
                        else
                        {
                            // Do nothing
                        }
                    }
                    else if(vLhsTypeIntegral.getSize() < vRhsTypeIntegral.getSize())
                    {
                        typeEnforce(vRhsTypeIntegral, vLhsInstr, vLhsInstr, true);
                    }
                    else if(vLhsTypeIntegral.getSize() > vRhsTypeIntegral.getSize())
                    {
                        typeEnforce(vLhsTypeIntegral, vRhsInstr, vRhsInstr, true);
                    }
                    else
                    {
                        if(vLhsTypeIntegral.isSigned() && !vRhsTypeIntegral.isSigned())
                        {
                            typeEnforce(vRhsTypeIntegral, vLhsInstr, vLhsInstr, true);
                        }
                        else if(!vLhsTypeIntegral.isSigned() && vRhsTypeIntegral.isSigned())
                        {
                            typeEnforce(vLhsTypeIntegral, vRhsInstr, vRhsInstr, true);
                        }
                        else
                        {
                            // Do nothing if they are the same type
                        }
                    }
                }
                else
                {
                    // See issue #141: Binary Operators support for non-Integer types (https://deavmi.assigned.network/git/tlang/tlang/issues/141)
                    ERROR("FIXME: We need to add support for this, class equality, and others like floats");
                }

                
                /**
                 * Refresh types as instructions may have changed in
                 * the above enforcement call
                 */
                vRhsType = vRhsInstr.getInstrType();
                vLhsType = vLhsInstr.getInstrType();

                /** 
                 * We now will check to make sure the types
                 * match, if not an error is thrown.
                 *
                 * We will also then set the instruction's
                 * type to one of the two (they're the same
                 * so it isn't as if it matters). But the
                 * resulting instruction should be of the type
                 * of its components - that's the logic.
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
                Context uOpCtx = unaryOpExp.getContext();
                assert(uOpCtx);
                SymbolType unaryOperator = unaryOpExp.getOperator();
                
                /* The type of the eventual UnaryOpInstr */
                Type unaryOpType;
                

                /**
                * Typechecking (TODO)
                */
                Value expInstr = cast(Value)popInstr();

                // Validate the expression
                validate(InstrCtx(uOpCtx.getContainer()), expInstr);

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
                    DEBUG("Type popped: "~to!(string)(expType));

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
                    ERROR("UnaryOperatorExpression: This should NEVER happen: "~to!(string)(unaryOperator));
                    assert(false);
                }
                

             
                

                // TODO: For type checking and semantics we should be checking WHAT is being ampersanded
                // ... as in we should only be allowing Ident's to be ampersanded, not, for example, literals
                // ... such a check can be accomplished via runtime type information of the instruction above
                
                
                UnaryOpInstr addInst = new UnaryOpInstr(expInstr, unaryOperator);
                DEBUG("Made unaryop instr: "~to!(string)(addInst));
                addInstr(addInst);

                addInst.setInstrType(unaryOpType);
            }
            /* Function calls */
            else if(cast(FunctionCall)statement)
            {
                FunctionCall funcCall = cast(FunctionCall)statement;
                assert(funcCall.getContext());
                DEBUG("FuncCall ctx: ", funcCall.getContext());
                assert(funcCall.getContext().getContainer());
                DEBUG("FuncCall ctx (container): ", funcCall.getContext().getContainer());

                ERROR("Name of func call: "~funcCall.getName());

                // Parameter count (to know how many to pop)
                size_t argCount = funcCall.getArgCount();

                // Create new call instruction
                FuncCallInstr funcCallInstr = new FuncCallInstr(funcCall.getName(), argCount);

                // Pop off the arguments back to front and add them
                while(argCount)
                {
                    Instruction curInstr = popInstr();
                    assert(curInstr);
                    Value curInstr_V = cast(Value)curInstr;
                    assert(curInstr_V);

                    funcCallInstr.setEvalInstr(argCount-1, curInstr_V);
                    argCount--;
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

                /* Add instruction to top of stack */
                addInstr(funcCallInstr);
            }
            /* Type cast operator */
            else if(cast(CastedExpression)statement)
            {
                CastedExpression castedExpression = cast(CastedExpression)statement;
                Context ctx = castedExpression.getContext();
                assert(ctx);
                DEBUG("Context: "~to!(string)(castedExpression.context));
                DEBUG("ParentOf: "~to!(string)(castedExpression.parentOf()));
                
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

                // Validate the uncasted expression instruction
                validate(InstrCtx(ctx.getContainer()), uncastedInstruction);

                /* Extract the type of the expression being casted */
                Type typeBeingCasted = uncastedInstruction.getInstrType();
                DEBUG("TypeCast [FromType: "~to!(string)(typeBeingCasted)~", ToType: "~to!(string)(castToType)~"]");
                

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
                Context ctx = arrayIndex.getContext();

                Type accessType;

                /* Pop the thing being indexed (the indexTo expression) */
                Value indexToInstr = cast(Value)popInstr();

                // Validate the thing-being-indexed instruction
                validate(InstrCtx(ctx.getContainer()), indexToInstr);

                Type indexToType = indexToInstr.getInstrType();
                assert(indexToType);
                DEBUG("ArrayIndex: Type of `indexToInstr`: "~indexToType.toString());

                /* Pop the index instruction (the index expression) */
                Value indexInstr = cast(Value)popInstr();

                // Validate the index instruction
                validate(InstrCtx(ctx.getContainer()), indexInstr);

                /* Obtain the type of the index instruction */
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
                ERROR("isStackArray (being indexed-on)?: "~to!(string)(isStackArray));


               
                // /* The type of what is being indexed on */
                // Type indexingOnType = arrayRefInstruction.getInstrType();
                // gprintln("Indexing-on type: "~indexingOnType.toString(), DebugType.WARNING);


                /* Stack-array type `<compnentType>[<size>]` */
                if(isStackArray)
                {
                    StackArray stackArray = cast(StackArray)indexToType;
                    accessType = stackArray.getComponentType();
                    DEBUG("ArrayIndex: Stack-array access");


                    ERROR("<<<<<<<< STCK ARRAY INDEX CODE GEN >>>>>>>>");



                    /**
                    * Codegen and type checking
                    *
                    * 1. Set the type (TODO)
                    * 2. Set the context (TODO)
                    */
                    StackArrayIndexInstruction stackArrayIndexInstr = new StackArrayIndexInstruction(indexToInstr, indexInstr);
                    stackArrayIndexInstr.setInstrType(accessType);
                    stackArrayIndexInstr.setContext(arrayIndex.context);

                    ERROR("IndexTo: "~indexToInstr.toString());
                    ERROR("Index: "~indexInstr.toString());
                    ERROR("Stack ARray type: "~stackArray.getComponentType().toString());

                    

                    // assert(false);
                    generatedInstruction = stackArrayIndexInstr;
                }
                /* Array type `<componentType>[]` */
                else if(cast(Pointer)indexToType)
                {
                    DEBUG("ArrayIndex: Pointer access");

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
                    ERROR("Indexing to an entity other than a stack array or pointer!");
                    assert(false);
                }



                // TODO: context (arrayIndex)

                DEBUG("ArrayIndex: [toInstr: "~indexToInstr.toString()~", indexInstr: "~indexInstr.toString()~"]");

                ERROR("Array index not yet supported");
                // assert(false);

                /* Push the instruction to the top of the stack */
                addInstr(generatedInstruction);

                /* Set context to instruction */
                generatedInstruction.setContext(ctx);
                assert(generatedInstruction.getContext());

                printCodeQueue();
            }
            else
            {
                ERROR("This ain't it chief");
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
            variableName = resolver.generateName(this.program, assignTo);
            DEBUG("VariableAssignmentNode: "~to!(string)(variableName));

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
            WARN("VaribleAssignmentNode(): Just popped off valInstr?: "~to!(string)(valueInstr));


            Type rightHandType = valueInstr.getInstrType();
            DEBUG("RightHandType (assignment): "~to!(string)(rightHandType));

            

        
            DEBUG(valueInstr is null);/*TODO: FUnc calls not implemented? Then is null for simple_1.t */
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
            Context ctx = variablePNode.getContext();
            assert(ctx);
            DEBUG("HELLO FELLA");

            /* Add an entry to the reference counting map */
            touch(variablePNode);

            /* Extract name and lookup type */
            string variableName = variablePNode.getName();
            Type variableDeclarationType = getType(ctx.getContainer(), variablePNode.getType());


            // Check if this variable declaration has an assignment attached
            Value assignmentInstr;
            if(variablePNode.getAssignment())
            {
                Instruction poppedInstr = popInstr();
                assert(poppedInstr);

                // Validate the instruction
                validate(InstrCtx(ctx.getContainer()), poppedInstr);

                // Obtain the value instruction of the variable assignment
                // ... along with the assignment's type
                assignmentInstr = cast(Value)poppedInstr;
                assert(assignmentInstr);
                Type assignmentType = assignmentInstr.getInstrType();
                assert(assignmentType);

                /** 
                 * Here we can call the `typeEnforce` with the popped
                 * `Value` instruction and the type to coerce to
                 * (our variable's type)
                 */
                typeEnforce(variableDeclarationType, assignmentInstr, assignmentInstr, true);
                assert(isSameType(variableDeclarationType, assignmentInstr.getInstrType())); // Sanity check
            }

            /* Generate a variable declaration instruction and add it to the codequeue */
            VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4, variableDeclarationType, assignmentInstr);
            varDecInstr.setContext(variablePNode.context);
            addInstrB(varDecInstr);

            /* Mark as declared (and pass in auxillary information for reporting) */
            declare(variablePNode, ReportData(varDecInstr));
        }
        /* TODO: Add class init, see #8 */
        else if(cast(tlang.compiler.typecheck.dependency.classes.classStaticDep.ClassStaticNode)dnode)
        {
            /* Extract the class node and create a static allocation instruction out of it */
            Clazz clazzPNode = cast(Clazz)dnode.getEntity();
            string clazzName = resolver.generateName(this.program, clazzPNode);
            ClassStaticInitAllocate clazzStaticInitAllocInstr = new ClassStaticInitAllocate(clazzName);

            /* Add this static initialization to the list of global allocations required */
            addInit(clazzStaticInitAllocInstr);
        }
        /* AssignmentTo dependency node */
        else if(cast(AssignmentTo)dnode)
        {
            Value toInstr = cast(Value)popInstr();
            DEBUG("toInstr: ", toInstr);
            assert(toInstr);
            
            // Set out-of-band data
            setAssignment_to(toInstr);
        }
        /* AssignmentOf dependency node */
        else if(cast(AssignmentOf)dnode)
        {
            Value ofInstr = cast(Value)popInstr();
            DEBUG("ofInstr: ", ofInstr);
            assert(ofInstr);

            // Set out-of-band data
            setAssignment_of(ofInstr);
        }
        /* It will pop a bunch of shiiit */
        /* TODO: ANy statement */
        else if(cast(tlang.compiler.typecheck.dependency.core.DNode)dnode)
        {
            /* TODO: Get the STatement */
            Statement statement = dnode.getEntity();

            DEBUG("Generic DNode typecheck(): Begin (examine: "~to!(string)(dnode)~" )");


            /* Assignment_V2 (works in tandum with AssignmentTo and AssignmentOf */
            if(cast(Assignment_V2)statement)
            {
                // Extract out-of-band data
                debug_assData(); // Debugging
                Value toEntityInstr = getAssignment_to();
                Value assignmentInstr = getAssignment_of();
                reset_assData();

                // TODO: Handle `toEntityInstr` which is `FetchValueInstr`
                // ... and those which are other sorts like `ArrayIndexInstr`

                // Assigning to a variable
                if(cast(FetchValueVar)toEntityInstr)
                {
                    // The entity being assigned to
                    FetchValueVar toEntityInstrVV = cast(FetchValueVar)toEntityInstr;
                    Context toCtx = toEntityInstr.getContext();
                    assert(toCtx);
                    DEBUG("target: ", toEntityInstrVV.getTarget());
                    Variable ent = cast(Variable) resolver.resolveBest(toCtx.getContainer(), toEntityInstrVV.getTarget());
                    assert(ent);
                    Type variableDeclarationType = getType(toCtx.getContainer(), ent.getType());

                    /**
                     * Validate the "to" instruction (the instruction representing
                     * the left-hand side of the assignment).
                     *
                     * We do this incase it was nto yet already validated, helps
                     * with things like touch()-counting
                     */
                    validate(InstrCtx(toCtx.getContainer()), toEntityInstrVV);


                    // Validate the instruction being assigned (the expression)
                    validate(InstrCtx(toCtx.getContainer()), assignmentInstr);

                    // Type of expression being assigned
                    Type assignmentType = assignmentInstr.getInstrType();
                    assert(assignmentType);

                    DEBUG(format("Assigning to '%s' of type: %s", ent, variableDeclarationType));
                    DEBUG(format("Value being assigned: %s", assignmentType));

                    /**
                    * Here we will do the enforcing of the types
                    *
                    * Will will allow coercion of the provided
                    * type (the value being assigned to our variable)
                    * to the to-type (our Variable's declared type)
                    */
                    typeEnforce(variableDeclarationType, assignmentInstr, assignmentInstr, true);
                    assert(isSameType(variableDeclarationType, assignmentInstr.getInstrType())); // Sanity check

                    /* Generate a variable assignment instruction and add it to the codequeue */
                    VariableAssignmentInstr vAInstr = new VariableAssignmentInstr(toEntityInstrVV.getTarget(), assignmentInstr);
                    vAInstr.setContext(statement.getContext());
                    addInstrB(vAInstr);
                }
                // Stack array indexing
                else if(cast(StackArrayIndexInstruction)toEntityInstr)
                {
                    StackArrayIndexInstruction arrayRefInstruction = cast(StackArrayIndexInstruction)toEntityInstr;
                    Context arrRefInstrCtx = arrayRefInstruction.getContext();
                    assert(arrRefInstrCtx);

                    // Validate the instruction being assigned (expression being assigned)
                    validate(InstrCtx(arrRefInstrCtx.getContainer()), assignmentInstr);

                    DEBUG("ArrayRefInstruction: ", arrayRefInstruction);
                    DEBUG("AssigmmentVal instr: ", assignmentInstr);

                    StackArrayIndexAssignmentInstruction stackArrAssInstr = new StackArrayIndexAssignmentInstruction
                    (
                        new ArrayIndexInstruction
                        (
                            arrayRefInstruction.getIndexedToInstr(),
                            arrayRefInstruction.getIndexInstr()
                        ),
                        assignmentInstr
                    );

                    /* Set the context */
                    stackArrAssInstr.setContext(arrRefInstrCtx);

                    /* Add to back of code queue */
                    addInstrB(stackArrAssInstr);
                }
                // Assigning to an index at an array
                else if(cast(ArrayIndexInstruction)toEntityInstr)
                {
                    ArrayIndexInstruction arrayRefInstruction = cast(ArrayIndexInstruction)toEntityInstr;
                    Context arrRefInstrCtx = arrayRefInstruction.getContext();
                    assert(arrRefInstrCtx);

                    DEBUG("ArrayRefInstruction: ", arrayRefInstruction);
                    DEBUG("AssigmmentVal instr: ", assignmentInstr);

                    // Validate the instruction being assigned (expression being assigned)
                    validate(InstrCtx(arrRefInstrCtx.getContainer()), assignmentInstr);

                    /* The type of what is being indexed on */
                    Type indexingOnType = arrayRefInstruction.getInstrType();
                    WARN("Indexing-on type: "~indexingOnType.toString());
                    WARN("Indexing-on type: "~indexingOnType.classinfo.toString());


                    ArrayIndexAssignmentInstruction arrDerefAssInstr = new ArrayIndexAssignmentInstruction
                    (
                        arrayRefInstruction,
                        assignmentInstr
                    );

                    /* Add the instruction */
                    addInstrB(arrDerefAssInstr);
                }
            }
            /**
            * Return statement (ReturnStmt)
            */
            else if(cast(ReturnStmt)statement)
            {
                ReturnStmt returnStatement = cast(ReturnStmt)statement;
                Context ctx = returnStatement.getContext();
                assert(ctx);

                Function funcContainer = cast(Function)resolver.findContainerOfType(Function.classinfo, returnStatement);

                /* Generated return instruction */
                ReturnInstruction returnInstr;

                /**
                 * Ensure that the `ReturnStmt` is finally parented
                 * by a `Function`
                 */
                if(!funcContainer)
                {
                    throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, "A return statement can only appear in the body of a function");
                }

                /**
                 * Extract information about the finally-parented `Function`
                 */
                string functionName = resolver.generateName(funcContainer.parentOf(), funcContainer);
                Type functionReturnType = getType(funcContainer, funcContainer.getType());
                

                /**
                * Codegen
                *
                * (1 and 2 only apply for return statements with an expression)
                *
                * 1. Pop the expression on the stack
                * 2. Create a new ReturnInstruction with the expression instruction
                * embedded in it
                */

                /* If the function's return type is void */
                if(isSameType(functionReturnType, getType(cast(Container)funcContainer, "void")))
                {
                    /* It is an error to have a return expression if function is return void */
                    if(returnStatement.hasReturnExpression())
                    {
                        throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, "Function '"~functionName~"' of type void cannot have a return expression");
                    }
                    /* If we don't have an expression (expected) */
                    else
                    {
                        /* Generate the instruction */
                        returnInstr = new ReturnInstruction();
                    }
                }
                /* If there is a non-void return type */
                else
                {
                    /* We should have an expression in the non-void case */
                    if(returnStatement.hasReturnExpression())
                    {
                        Value returnExpressionInstr = cast(Value)popInstr();
                        assert(returnExpressionInstr);

                        // Validate the return instruction (expression)
                        validate(InstrCtx(ctx.getContainer()), returnExpressionInstr);

                        Type returnExpressionInstrType = returnExpressionInstr.getInstrType();

                        /**
                         * Type check the return expression's type with that of the containing
                         * function's retur type, if they don't match attempt coercion.
                         *
                         * On type check failure, an exception is thrown.
                         *
                         * On success, the `retjrnExpressionInstr` MAY be updated and then
                         * we continue on.
                         */
                        typeEnforce(functionReturnType, returnExpressionInstr, returnExpressionInstr, true);

                        /* Generate the instruction */
                        returnInstr = new ReturnInstruction(returnExpressionInstr);
                    }
                    /* If not then this is an error */
                    else
                    {
                        throw new TypeCheckerException(this, TypeCheckerException.TypecheckError.GENERAL_ERROR, "Function '"~functionName~"' of has a type therefore it requires an expression in the return statement");
                    }
                }
                
                /** 
                 * Codegen (continued)
                 *
                 * 3. Set the Context of the instruction
                 * 4. Add this instruction back
                 */
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
                    Context ctx = branch.getContext();
                    assert(ctx);

                    // Pop off an expression instruction (if it exists)
                    Value branchConditionInstr;
                    if(branch.hasCondition())
                    {
                        Instruction instr = popInstr();
                        DEBUG("BranchIdx: "~to!(string)(branchIdx));
                        DEBUG("Instr is: "~to!(string)(instr));
                        branchConditionInstr = cast(Value)instr;
                        assert(branchConditionInstr);

                        // Validate the `Value`-based instruction
                        validate(InstrCtx(ctx.getContainer()), branchConditionInstr);
                    }

                    // Get the number of body instructions to pop
                    ulong bodyCount = branch.getBody().length;
                    ulong i = 0;
                    Instruction[] bodyInstructions;

                    
                    while(i < bodyCount)
                    {
                        Instruction bodyInstr = tailPopInstr();
                        bodyInstructions~=bodyInstr;

                        DEBUG("tailPopp'd("~to!(string)(i)~"/"~to!(string)(bodyCount-1)~"): "~to!(string)(bodyInstr));

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

                DEBUG("If!");
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
                    DEBUG("Still looking at dependency construction in this thing (do while loops )");
                    assert(false);
                }

                Branch branch = whileLoop.getBranch();
                Context ctx = branch.getContext();
                assert(ctx);

                /* The condition `Value` instruction should be on the stack */
                Value valueInstrCondition = cast(Value)popInstr();
                assert(valueInstrCondition);

                // Validate the `Value`-based instruction
                validate(InstrCtx(ctx.getContainer()), valueInstrCondition);

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
                Context ctx = forLoop.getContext();
                assert(ctx);

                /* Pop-off the Value-instruction for the condition */
                Value valueInstrCondition = cast(Value)popInstr();
                assert(valueInstrCondition);

                // Validate the condition instruction
                validate(InstrCtx(ctx.getContainer()), valueInstrCondition);

                /* Calculate the number of instructions representing the body to tailPopInstr() */
                ulong bodyTailPopNumber = forLoop.getBranch().getStatements().length;
                DEBUG("bodyTailPopNumber: "~to!(string)(bodyTailPopNumber));

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

                DEBUG("Look at that y'all, cause this is it: "~to!(string)(branch));
            }
            /**
            * Dereferencing pointer assignment statement (PointerDereferenceAssignment)
            */
            else if(cast(PointerDereferenceAssignment)statement)
            {
                PointerDereferenceAssignment ptrDerefAss = cast(PointerDereferenceAssignment)statement;
                Context ctx = ptrDerefAss.getContext();
                assert(ctx);
                
                /* Pop off the pointer dereference expression instruction (LHS) */
                Value lhsPtrExprInstr = cast(Value)popInstr();
                assert(lhsPtrExprInstr);

                // Validate the pointer dereference instruction (LHS)
                validate(InstrCtx(ctx.getContainer()), lhsPtrExprInstr);

                /* Pop off the assignment instruction (RHS expression) */
                Value rhsExprInstr = cast(Value)popInstr();
                assert(rhsExprInstr);

                // Validate the assignment instruction (RHS)
                validate(InstrCtx(ctx.getContainer()), rhsExprInstr);

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
             * Standalone expression statements
             */
            else if(cast(ExpressionStatement)statement)
            {
                ExpressionStatement exprStmt = cast(ExpressionStatement)statement;
                Context ctx = exprStmt.getContext();
                assert(ctx);

                /* Pop a single `Value`-based instruction off the stack */
                Value valInstr = cast(Value)popInstr();

                /* Perform validation on the `Value`-based instruction */
                validate(InstrCtx(ctx.getContainer()), valInstr);

                /**
                 * If it is anything other than a
                 * direct function call (i.e. a
                 * `FuncCallInstr`) then warn
                 * about unused values
                 *
                 * FIXME: Remove this as idk
                 * what it does
                 */
                if(!cast(FuncCallInstr)valInstr)
                {
                    WARN
                    (
                        format
                        (
                            "You may have unused values in this non-function call statement-level expression: %s",
                            valInstr
                        )
                    );
                }

                /* Create new instruction embedding the `valInstr` */
                ExpressionStatementInstruction instr = new ExpressionStatementInstruction(valInstr);

                /* Copy over nested instruction's context */
                instr.setContext(valInstr.getContext());

                /* Add the instruction */
                addInstrB(instr);
            }
            /* Case of no matches */
            else
            {
                WARN("NO MATCHES FIX ME FOR: "~to!(string)(statement));
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
        DEBUG("Action list: "~to!(string)(actionList));

        /**
        * Loop through each dependency-node in the action list
        * and perform the type-checking/code generation
        */
        foreach(DNode node; actionList)
        {
            DEBUG("Process: "~to!(string)(node));

            /* Print the code queue each time */
            DEBUG("sdfhjkhdsfjhfdsj 1");
            printCodeQueue();
            DEBUG("sdfhjkhdsfjhfdsj 2");

            /* Type-check/code-gen this node */
            typeCheckThing(node);
            writeln("--------------");
        }


        writeln("\n################# Results from type-checking/code-generation #################\n");

        
        /* Print the init queue */
        DEBUG("<<<<< FINAL ALLOCATE QUEUE >>>>>");
        printInitQueue();

        /* Print the code queue */
        DEBUG("<<<<< FINAL CODE QUEUE >>>>>");
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

        // TODO: Below is somewhat badly named
        // as it handles the pointer types `<type>*`
        // and accounts for more than just built-in
        // types then
        /* Check if the type is built-in */
        foundType = getBuiltInType(this, c, typeString);

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
        // TODO: Ensure this is CORRECT! (MODMAN)
        /* Run the meta-processor on the AST tree (starting from the Module) */
        meta.process(this.program);

        // TODO: Ensure this is CORRECT! (MODMAN)
        /* Process all pseudo entities of the program's modules */
        foreach(Statement curModule; this.program.getStatements())
        {
            processPseudoEntities(cast(Module)curModule);
        }

        /* Process all enumeration types of the program's modules */
        foreach(Statement curModule; this.program.getStatements())
        {
            processEnums(cast(Module)curModule);
        }

        // TODO: Ensure this is CORRECT! (MODMAN)
        /**
        * Make sure there are no name collisions anywhere
        * in the Module with an order of precedence of
        * Classes being declared before Functions and
        * Functions before Variables
        */
        foreach(Statement curModule; this.program.getStatements())
        {
            checkContainerCollision(cast(Module)curModule); /* TODO: Rename checkContainerCollision */
        }

        /* TODO: Now that everything is defined, no collision */
        /* TODO: Do actual type checking and declarations */
        dependencyCheck();
    }

    // TODO: This will have to be recursive because of where we
    // will allow these top be declared
    private void processEnums(Container c)
    {
        bool allEnums(Entity entity)
        {
            return cast(Enum)entity !is null;
        }

        Entity[] entities;
        resolver.resolveWithin(c, &allEnums, entities);

        foreach(Enum e; cast(Enum[])entities)
        {
            processEnum(e);
        }

        // panic("sd");
    }

    import tlang.compiler.symbols.typing.enums : Enum;
    private void processEnum(Enum e)
    {
        DEBUG("Analyzing enumeration '", e, "'...");

        // Enum cannot have NO members
        // TODO: Make optional
        if(e.members().length == 0)
        {
            throw new TypeCheckerException
            (
                TypeCheckerException.TypecheckError.GENERAL_ERROR,
                format
                (
                    "Enumeration type %s cannot have no members",
                    e.getName()
                )
            );
        }

        // FIXME: Remove below, oly needd on-demand
        import tlang.compiler.symbols.typing.enums : enumCheck;
        Type e_mem_t; // TODO: Store this for lookup somewhere with a `Type[Enum]` map
        enumCheck(this, e, e_mem_t);
        DEBUG("Member type: ", e_mem_t);
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
            DEBUG("Class: " ~ clazz.getName() ~ ": ParentInheritList: " ~ to!(
                    string)(parentClasses));

            /* Try resolve all of these */
            foreach (string parent; parentClasses)
            {
                /* Find the named entity */
                Entity namedEntity;

                /* Check if the name is rooted */
                string[] dotPath = split(parent, '.');
                DEBUG(dotPath.length);

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
                            expect("Cannot inherit from self");
                        }
                    }
                    /* Error */
                else
                    {
                        expect("Can only inherit from classes");
                    }
                }
                /* If the entity doesn't exist then it is an error */
                else
                {
                    expect("Could not find any entity named " ~ parent);
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
    *
    * FIXME:
    *
    * (MODMAN) We need to know WHICH `Module` we
    * are currently examining when we do this such
    * that we can then fix the other `resolver`
    * calls when we `generateName`(s), else
    * we use the old `modulle` which is null
    * now.
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
        DEBUG("checkContainer(C): " ~ to!(string)(entities));

        foreach (Entity entity; entities)
        {
            // (MODMAN) TODO: We need to loop through each module and make
            // ... sure its name doesn't match with any of them
            foreach(Module curMod; program.getModules())
            {
                if(cmp(entity.getName(), curMod.getName()) == 0)
                {
                    throw new CollidingNameException(this, curMod, entity, c);
                }
            }
            

            /**
            * If the current entity's name matches the container then error
            */
            if (cmp(containerEntity.getName(), entity.getName()) == 0)
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
                // (MODMAN) This will need to be fixed (anchored at the Program-level)
                string fullPath = resolver.generateName(this.program, entity);
                // (MODMAN) This will need to be fixed (anchored at the Program-level)
                string containerNameFullPath = resolver.generateName(this.program, containerEntity);
                DEBUG("Entity \"" ~ fullPath
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
                expect("Cannot define class \"" ~ resolver.generateName(this.program,
                        clazz) ~ "\" as one with same name, \"" ~ resolver.generateName(this.program,
                        resolver.resolveUp(c, clazz.getName())) ~ "\" exists in container \"" ~ resolver.generateName(
                        this.program, containerEntity) ~ "\"");
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
                    expect("Class \"" ~ resolver.generateName(this.program,
                            clazz) ~ "\" cannot be defined within container with same name, \"" ~ resolver.generateName(
                            this.program, containerEntity) ~ "\"");
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
            WARN("Check recursive " ~ to!(string)(clazz));

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

    /** 
     * Maps a given `Entity` to its reference
     * count. This includes the declaration
     * thereof.
     */
    private uint[Entity] entRefCounts;

    /** 
     * Increments the given entity's reference
     * count
     *
     * Params:
     *   entity = the entity
     */
    void touch(Entity entity)
    {
        // Create entry if not existing yet
        if(entity !in this.entRefCounts)
        {
            this.entRefCounts[entity] = 0;
        }

        // Increment count
        this.entRefCounts[entity]++;
    }

    /** 
     * Returns all variables which were declared
     * but not used
     *
     * Returns: the array of variables
     */
    public Variable[] getUnusedVariables()
    {
        Variable[] unused;
        foreach(Entity entity; getUnusedEntities())
        {
            Variable potVar = cast(Variable)entity;
            if(potVar)
            {
                unused ~= potVar;
            }
        }

        return unused;
    }

    /** 
     * Returns all functions which were declared
     * but not used
     *
     * Returns: the array of functions
     */
    public Function[] getUnusedFunctions()
    {
        Function[] unused;
        foreach(Entity entity; getUnusedEntities())
        {
            Function potFunc = cast(Function)entity;
            if(potFunc)
            {
                unused ~= potFunc;
            }
        }

        return unused;
    }

    /** 
     * Returns all entities which were declared
     * but not used
     *
     * Returns: the array of entities
     */
    public Entity[] getUnusedEntities()
    {
        Entity[] unused;
        foreach(Entity entity; this.entRefCounts.keys())
        {
            // 1 means it was declared
            if(!(this.entRefCounts[entity] > 1))
            {
                unused ~= entity;
            }
            // Anything more (refCount > 1) means a reference
            else
            {
                // TODO: change text based on entity typ[e]
                // FIXME: Only enable this when in debug builds
                DEBUG("Entity '", entity, "' is used ", this.entRefCounts[entity]-1, " many times");
            }
        }

        return unused;
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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();
    
    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity container = typeChecker.getResolver().resolveBest(modulle, "y");
        Entity colliderMember = typeChecker.getResolver().resolveBest(modulle, "y.y");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity container = typeChecker.getResolver().resolveBest(modulle, "y");
        Entity colliderMember = typeChecker.getResolver().resolveBest(modulle, "y.a.b.c.y");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity container = typeChecker.getResolver().resolveBest(modulle, "a.b.c");
        Entity colliderMember = typeChecker.getResolver().resolveBest(modulle, "a.b.c.c");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity memberFirst = typeChecker.getResolver().resolveBest(modulle, "a.b");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity ourClassA = typeChecker.getResolver().resolveBest(modulle, "a");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    try
    {
        /* Perform test */
        compiler.doTypeCheck();

        /* Shouldn't reach here, collision exception MUST occur */
        assert(false);
    }
    catch (CollidingNameException e)
    {
        Program program = compiler.getProgram();
        TypeChecker typeChecker = compiler.getTypeChecker();
        Module modulle = program.getModules()[0];

        /* Setup testing variables */
        Entity container = typeChecker.getResolver().resolveBest(modulle, "y");
        Entity colliderMember = typeChecker.getResolver().resolveBest(modulle, "y.y");

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
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    /* Perform test */
    compiler.doTypeCheck();

    /* TODO: Actually test generated code queue */
}

/** 
 * Tests the unused variable detection mechanism
 *
 * Case: Positive (unused variables exist)
 * Source file: source/tlang/testing/unused_vars.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_vars.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 1 unused variable and then
     * it should be named `j`
     */
    Variable[] unusedVars = tc.getUnusedVariables();
    assert(unusedVars.length == 1);
    Variable unusedVarActual = unusedVars[0];
    Variable unusedVarExpected = cast(Variable)tc.getResolver().resolveBest(compiler.getProgram().getModules()[0], "j");
    assert(unusedVarActual is unusedVarExpected);
}

/** 
 * Tests the unused variable detection mechanism
 *
 * Case: Negative (unused variables do NOT exist)
 * Source file: source/tlang/testing/unused_vars_none_1.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_vars_none_1.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 0 unused variables
     */
    Variable[] unusedVars = tc.getUnusedVariables();
    assert(unusedVars.length == 0);
}

/** 
 * Tests the unused variable detection mechanism
 *
 * Case: Negative (unused variables do NOT exist)
 * Source file: source/tlang/testing/unused_vars_none_2.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_vars_none_2.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 0 unused variables
     */
    Variable[] unusedVars = tc.getUnusedVariables();
    assert(unusedVars.length == 0);
}

/** 
 * Tests the unused functions detection mechanism
 *
 * Case: Positive (unused variables exist)
 * Source file: source/tlang/testing/unused_funcs.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_funcs.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 1 unused function and then
     * it should be named `thing`
     */
    Function[] unusedFuncs = tc.getUnusedFunctions();
    assert(unusedFuncs.length == 1);
    Function unusedFuncActual = unusedFuncs[0];
    Function unusedFuncExpected = cast(Function)tc.getResolver().resolveBest(compiler.getProgram().getModules()[0], "thing");
    assert(unusedFuncActual is unusedFuncExpected);
}

/** 
 * Tests the unused variable detection mechanism
 *
 * Case: Negative (unused variables do NOT exist)
 * Source file: source/tlang/testing/unused_funcs_none_1.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_funcs_none_1.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 0 unused functions
     */
    Function[] unusedFuncs = tc.getUnusedFunctions();
    assert(unusedFuncs.length == 0);
}

/** 
 * Tests the unused variable detection mechanism
 *
 * Case: Negative (unused variables do NOT exist)
 * Source file: source/tlang/testing/unused_funcs_none_2.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_funcs_none_2.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    compiler.doTypeCheck();
    TypeChecker tc = compiler.getTypeChecker();

    /**
     * There should be 0 unused functions
     */
    Function[] unusedFuncs = tc.getUnusedFunctions();
    assert(unusedFuncs.length == 0);
}

/** 
 * Tests the use-before-declare detection for
 * variable usage and variable declarations
 *
 * Case: Positive (use-before-declare is present)
 * Source file: source/tlang/testing/typecheck/use_before_declare.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/typecheck/use_before_declare.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    
    Exception eFound;
    try
    {
        compiler.doTypeCheck();
        assert(false);
    }
    catch(TypeCheckerException e)
    {
        eFound = e;
        assert(e.getError() == TypeCheckerException.TypecheckError.ENTITY_NOT_DECLARED);
    }

    assert(cast(TypeCheckerException)eFound !is null);
}

/** 
 * Tests the referencing of entities with
 * given names but which don't exist. This
 * case tests the case whereby an entity
 * is referenecd (an identity reference)
 * but which does not exist.
 *
 * Case: Positive (entity referenced does not exist)
 * Source file: source/tlang/testing/typecheck/use_but_not_found_var.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/typecheck/use_but_not_found_var.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    
    Exception eFound;
    try
    {
        compiler.doTypeCheck();
        assert(false);
    }
    catch(TypeCheckerException e)
    {
        eFound = e;
        assert(e.getError() == TypeCheckerException.TypecheckError.ENTITY_NOT_FOUND);
    }

    assert(cast(TypeCheckerException)eFound !is null);
}

/** 
 * Tests the referencing of entities with
 * given names but which don't exist. This
 * case tests the case of a function call
 * to a function which doesn't exist
 *
 * Case: Positive (entity referenced does not exist)
 * Source file: source/tlang/testing/typecheck/use_but_not_found_func.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/typecheck/use_but_not_found_func.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    
    Exception eFound;
    try
    {
        compiler.doTypeCheck();
        assert(false);
    }
    catch(TypeCheckerException e)
    {
        eFound = e;
        assert(e.getError() == TypeCheckerException.TypecheckError.ENTITY_NOT_FOUND);
    }

    assert(cast(TypeCheckerException)eFound !is null);
}

/** 
 * Tests applying the dot operator
 * where the left-hand side is the
 * name of a function, which is
 * not allowed.
 *
 * Case: Positive (it is the case)
 * Source file: source/tlang/testing/dotting/bad_dot.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/dotting/bad_dot.t";


    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, fileOutDummy);
    compiler.doLex();
    compiler.doParse();
    
    Exception eFound;
    try
    {
        compiler.doTypeCheck();
        assert(false);
    }
    catch(TypeCheckerException e)
    {
        eFound = e;
        assert(e.getError() == TypeCheckerException.TypecheckError.GENERAL_ERROR);
    }

    assert(cast(TypeCheckerException)eFound !is null);
}


