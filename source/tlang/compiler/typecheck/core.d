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
        if(this.config.hasConfig("typecheck:warnUnusedVars") & this.config.getConfig("typecheck:warnUnusedVars").getBoolean())
        {
            Variable[] unusedVariables = getUnusedVariables();
            WARN("There are "~to!(string)(unusedVariables.length)~" unused variables");
            if(unusedVariables.length)
            {
                foreach(Variable unusedVariable; unusedVariables)
                {
                    // TODO: Get a nicer name, full path-based
                    INFO("Variable '"~to!(string)(unusedVariable.getName())~"' is declared but never used");
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
                DEBUG("Negated literal: "~negativeLiteral);

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
                ERROR("Mashallah why are we here? BECAUSE we should just use ze-value-based genral case!: "~providedInstruction.classinfo.toString());
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
                    IntegerLiteral integerLitreal = cast(IntegerLiteral)statement;

                    /**
                     * Determine the type of this value instruction by finding
                     * the encoding of the integer literal (part of doing issue #94)
                     */
                    Type literalEncodingType;
                    if(integerLitreal.getEncoding() == IntegerLiteralEncoding.SIGNED_INTEGER)
                    {
                        literalEncodingType = getType(this.program, "int");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.UNSIGNED_INTEGER)
                    {
                        literalEncodingType = getType(this.program, "uint");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.SIGNED_LONG)
                    {
                        literalEncodingType = getType(this.program, "long");
                    }
                    else if(integerLitreal.getEncoding() == IntegerLiteralEncoding.UNSIGNED_LONG)
                    {
                        literalEncodingType = getType(this.program, "ulong");
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
                assert(g);

                /* FIXME: It would seem that g.getContext() is returning null, so within function body's context is not being set */
                DEBUG("VarExp: "~g.getName());
                DEBUG(g.getContext());
                Entity gVar = cast(Entity)resolver.resolveBest(g.getContext().getContainer(), g.getName());
                DEBUG("gVar nullity?: "~to!(string)(gVar is null));


                // TODO: Throw exception if name is not found

                /* TODO; Above crashes when it is a container, eish baba - from dependency generation with `TestClass.P.h` */
                string variableName = resolver.generateName(this.program, gVar);
                variableName = g.getName();

                /* Type determined for instruction */
                Type instrType;

                // If a module is being referred to
                if(cast(Module)gVar)
                {
                    instrType = getType(this.program, "module");
                }
                // If it is some kind-of typed entity
                else if(cast(TypedEntity)gVar)
                {
                    TypedEntity typedEntity = cast(TypedEntity)gVar;
                    instrType = getType(gVar.getContext().getContainer(), typedEntity.getType());
                }
                //
                else
                {
                    panic(format("Please add support for VariableExpression typecheck/codegen for handling: %s", gVar.classinfo));
                }


                

                DEBUG("Yaa, it's rewind time");


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
                fVV.setInstrType(instrType);
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

                Type vRhsType = vRhsInstr.getInstrType();
                Type vLhsType = vLhsInstr.getInstrType();
                DEBUG("vLhsType: ", vLhsType);
                DEBUG("vRhsType: ", vRhsType);

                DEBUG("Sir shitsalot");


                if(binOperator == SymbolType.DOT)
                {
                    // panic("Implement dot operator typecheck/codegen");

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
                                FetchValueVar newfetchInstr = new FetchValueVar(newName, 8);
                                newfetchInstr.setInstrType(getType(this.program, "container"));
                                addInstr(newfetchInstr);

                                return;
                            }

                            // If member is a variable
                            else if(cast(Variable)memberEnt)
                            {
                                DEBUG("memberEnt is a variable");
                                
                                // Push the right hand side then
                                // BACK to the top of stack
                                FetchValueVar rightFetch = cast(FetchValueVar)vRhsInstr;
                                addInstr(rightFetch);
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
                            addInstr(funcCallRight);
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

                // Find the top-level container of the function being called
                // and then use this as the container to resolve our function
                // being-called to (as a starting point)
                Module belongsTo = cast(Module)resolver.findContainerOfType(Module.classinfo, funcCall);
                assert(belongsTo);

                /* TODO: Look up func def to know when popping stops (types-based delimiting) */
                Function func = cast(Function)resolver.resolveBest(belongsTo, funcCall.getName());
                assert(func);
                VariableParameter[] paremeters = func.getParams();

                /* TODO: Pass in FUnction, so we get function's body for calling too */
                DEBUG(format("funcCall.getName() %s", funcCall.getName()));
                FuncCallInstr funcCallInstr = new FuncCallInstr(funcCall.getName(), paremeters.length);
                ERROR("Name of func call: "~func.getName());

                /* If there are paremeters for this function (as per definition) */
                if(!paremeters.length)
                {
                    ERROR("No parameters for deez nuts: "~func.getName());
                }
                /* Pop all args per type */
                else
                {
                    ulong parmCount = paremeters.length-1;
                    ERROR("Kachow: "~to!(string)(parmCount));

                    while(!isInstrEmpty())
                    {
                        Instruction instr = popInstr();
                        
                        Value valueInstr = cast(Value)instr;
                        

                        /* Must be a value instruction */
                        if(valueInstr && parmCount!=-1)
                        {
                            /* TODO: Determine type and match up */
                            DEBUG("Yeah");
                            DEBUG(valueInstr);
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



                            /**
                                * We need to enforce the `valueInstr`'s' (the `Value`-based
                                * instruction being passed as an argument) type to be that
                                * of the `parmType` (the function's parameter type)
                                */
                            typeEnforce(parmType, valueInstr, valueInstr, true);

                            /**
                                * Refresh the `argType` as `valueInstr` may have been
                                * updated and we need the new type
                                */
                            argType = valueInstr.getInstrType();
                            

                            // Sanity check
                            assert(isSameType(argType, parmType));

                            
                            /* Add the instruction into the FunctionCallInstr */
                            funcCallInstr.setEvalInstr(parmCount, valueInstr);
                            DEBUG(funcCallInstr.getEvaluationInstructions());
                            
                            /* Decrement the parameter index (right-to-left, so move to left) */
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

                /* Add instruction to top of stack */
                addInstr(funcCallInstr);

                /* Set the Value instruction's type */
                Type funcCallInstrType = getType(func.parentOf(), func.getType());
                funcCallInstr.setInstrType(funcCallInstrType);
            }
            /* Type cast operator */
            else if(cast(CastedExpression)statement)
            {
                CastedExpression castedExpression = cast(CastedExpression)statement;
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
                Type accessType;

                /* Pop the thing being indexed (the indexTo expression) */
                Value indexToInstr = cast(Value)popInstr();
                Type indexToType = indexToInstr.getInstrType();
                assert(indexToType);
                DEBUG("ArrayIndex: Type of `indexToInstr`: "~indexToType.toString());

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

                addInstr(generatedInstruction);

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
            DEBUG("HELLO FELLA");

            string variableName = resolver.generateName(this.program, variablePNode);
            DEBUG("HELLO FELLA (name): "~variableName);
            

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
                    Variable ent = cast(Variable) resolver.resolveBest(toCtx.getContainer(), toEntityInstrVV.getTarget());
                    assert(ent);
                    Type variableDeclarationType = getType(toCtx.getContainer(), ent.getType());

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

                    DEBUG("ArrayRefInstruction: ", arrayRefInstruction);
                    DEBUG("AssigmmentVal instr: ", assignmentInstr);



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
            /* VariableAssignmentStdAlone */
            else if(cast(VariableAssignmentStdAlone)statement)
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

                    // Pop off an expression instruction (if it exists)
                    Value branchConditionInstr;
                    if(branch.hasCondition())
                    {
                        Instruction instr = popInstr();
                        DEBUG("BranchIdx: "~to!(string)(branchIdx));
                        DEBUG("Instr is: "~to!(string)(instr));
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
            else if(cast(ExpressionStatement)statement)
            {
                ExpressionStatement exprStmt = cast(ExpressionStatement)statement;

                /* Pop a single `Value`-based instruction off the stack */
                Value valInstr = cast(Value)popInstr();

                /**
                 * If it is anything other than a
                 * direct function call (i.e. a
                 * `FuncCallInstr`) then warn
                 * about unused values
                 */
                if(!cast(FuncCallInstr)valInstr)
                {
                    WARN(format("You may have unused values in this non-function call statement-level expression: %s", valInstr));
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
     * Maps a given `Variable` to its reference
     * count. This includes the declaration
     * thereof.
     */
    private uint[Variable] varRefCounts;

    /** 
     * Increments the given variable's reference
     * count
     *
     * Params:
     *   variable = the variable
     */
    void touch(Variable variable)
    {
        // Create entry if not existing yet
        if(variable !in this.varRefCounts)
        {
            this.varRefCounts[variable] = 0;    
        }

        // Increment count
        this.varRefCounts[variable]++;
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
        foreach(Variable variable; this.varRefCounts.keys())
        {
            if(!(this.varRefCounts[variable] > 1))
            {
                unused ~= variable;
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
 * Source file: source/tlang/testing/unused_vars_none.t
 */
unittest
{
    // Dummy field out
    File fileOutDummy;
    import tlang.compiler.core;

    string sourceFile = "source/tlang/testing/unused_vars_none.t";


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