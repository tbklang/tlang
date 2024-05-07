module tlang.compiler.typecheck.dependency.core;

import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import std.conv : to;
import std.string : cmp;
import std.stdio;
import tlang.misc.logging;
import tlang.compiler.parsing.core;
import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.exceptions;
import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.typing.builtins;
import tlang.compiler.typecheck.dependency.exceptions : DependencyException, DependencyError, AccessViolation;
import tlang.compiler.typecheck.dependency.pool.interfaces;
import tlang.compiler.typecheck.dependency.pool.impls;
import tlang.compiler.typecheck.dependency.store.interfaces : IFuncDefStore;


/**
* Passed around
*
* 1. Contains containership (some Statements are not contained) so we need to track this
* 2. InitScope, STATIC or VIRTUAL permission
* 3. `allowUp`, when resolving names in this Context use
* resolveBest instead of resolveWithin (stay inside Context solely
* don't travel up parents)
*/
public final class Context
{
    // Required for cases where we need the functionality of the type checker
    // static TypeChecker tc;

    InitScope initScope;
    Container container;
    bool allowUp = true;

    this(Container container, InitScope initScope)
    {
        this.initScope = initScope;
        this.container = container;
    }

    public bool isAllowUp()
    {
        return allowUp;
    }

    public void noAllowUp()
    {
        allowUp = false;
    }

    public Container getContainer()
    {
        return container;
    }

    public override string toString()
    {
        return "Context [ContPtr(valid?): "~to!(string)(!(container is null))~", InitScope: "~to!(string)(initScope)~"]";
    }
}

/**
* FunctionData
*
* Contains the dependency tree for a function,
* it's name, context as to where it is declared
*
*TODO: TO getn this to work DNode and DNoeGenerator
* must become one to house `private static DNode root`
* and `private static DNode[] pool`, which means FunctionData
* may remain completely seperated from Module's DNode
*
* Of course DNode must have a FunctionData[] array irrespective
* of the sub-type of DNode as we look up data using it
* techncially it could be seperate, yeah, global function
*
* The FunctionData should, rather than Context perhaps,
* take in the DNode of the Modulle, to be able to idk
* maybe do some stuff
*/
public struct FunctionData
{
    public string name;
    public DNodeGenerator ownGenerator;
    public Function func;
    private Module belongsTo;

    public DNode generate()
    {
        return ownGenerator.generate();
    }

    /** 
     * Sets the module to which
     * this function is declared
     * within
     *
     * Params:
     *   mod = the `Module`
     */
    public void setOwner(Module mod)
    {
        this.belongsTo = mod;
    }

    /** 
     * Gets the module this
     * function is declared
     * within
     *
     * Returns: the `Module`
     */
    public Module getOwner()
    {
        return this.belongsTo;
    }

    public string getName()
    {
        return this.name;
    }
}

/**
* DNode
*
* Represents a dependency node which contains sub-dependencies,
* an associated Statement (to be initialized) and status flags
* as to whether the node has been visited yet and whether or
* not it has been initialized
*/
public class DNode
{
    /* The Statement to be initialized */
    protected Statement entity;

    protected string name;

    private bool visited;
    private bool complete;
    private DNode[] dependencies;

    this(Statement entity)
    {
        this.entity = entity;

        initName();
    }

    public void needs(DNode dependency)
    {
        dependencies ~= dependency;
    }

    public bool isVisisted()
    {
        return visited;
    }

    public void markVisited()
    {
        visited = true;
    }

    public void markCompleted()
    {
        complete = true;
    }

    public bool isCompleted()
    {
        return complete;
    }

    public Statement getEntity()
    {
        return entity;
    }

    public static ulong count(string bruh)
    {
        ulong i = 0;
        foreach(char character; bruh)
        {
            if(character == '.')
            {
                i++;
            }
        }

        return i;
    }

    public static ulong c = 0;


    public final string getName()
    {
        return name;
    }

    void forceName(string name)
    {
        this.name = name;
    }

    /**
    * Should be overriden or have something set
    * inherited variable, this should make the
    * implementation of `print()` a lot more
    * cleaner
    */
    private void initName()
    {
        name = "bruh";
    }

    // NOTE: Below may be useful just sfor sub-tree dependecy, idk why one would want that but we may as well make the API work everywhere
    // ... and in more cases :) for uniformity-sake (not urgent this case though as we don't plan on using it like that)
    // TODO: Add support later for relinearization even though not really a much needed feature
    // NOTE: We could also get rid of `markCompleted()` and then wipe visited and use that rather for tree generation/linearization
    private bool hasLinearized = false;
    private DNode[] linearizedNodes;
    private string dependencyTreeRepresentation;

    public void performLinearization()
    {
        if(hasLinearized)
        {
            throw new DependencyException(DependencyError.ALREADY_LINEARIZED);
        }
        else
        {
            // Perform the linearization on this DNode's `linearizedNodes` array
            dependencyTreeRepresentation = print(linearizedNodes);

            // Mark as done
            hasLinearized = true;
        }
    }

    public DNode[] getLinearizedNodes()
    {
        if(hasLinearized)
        {
            return linearizedNodes;
        }
        else
        {
            throw new DependencyException(DependencyError.NOT_YET_LINEARIZED);
        }
    }

    public string getTree()
    {
        if(hasLinearized)
        {
            return dependencyTreeRepresentation;
        }
        else
        {
            throw new DependencyException(DependencyError.NOT_YET_LINEARIZED);
        }
    }

    /** 
     * Performs the linearization and generates a tree whilst doing so.
     * The user provides the array to write into (a pointer to it).
     *
     * Params:
     *   destinationLinearList = the DNode[] to write the linearization into
     * Returns: a string representation of the dependency tree
     */
    private string print(ref DNode[] destinationLinearList)
    {
        string spaces = "                                                ";
        /* The tree */ /*TODO: Make genral to statement */
        string tree = "   ";


        tree ~= name;

        tree ~= "\n";
        c++;
        foreach(DNode dependancy; dependencies)
        {
            if(!dependancy.isCompleted())
            {
                dependancy.markCompleted();

               

                tree ~= spaces[0..(c)*3]~dependancy.print(destinationLinearList);
            }
            
        }

        markCompleted();

         /* TODO: I think using `isDone` we can linearise */
        DEBUG("Done/Not-done?: "~to!(string)(isDone));

        // TODO: What is this for and do we even need it? See issue #41 Problem 5
        if(isDone)
        {
            destinationLinearList ~= this;
        }

        c--;
        return tree;
    }

    // TODO: What is this for and do we even need it? See issue #41 Problem 5
    private bool isDone()
    {
        bool done = false;

        foreach(DNode dependency; dependencies)
        {
            if(!dependency.isCompleted())
            {
                return false;
            }
        }

        return true;
    }

    public override string toString()
    {
        return "[DNode: "~to!(string)(entity)~"]";
    }

    ulong getDepCount()
    {
        return this.dependencies.length;
    }

    /** 
     * Returns this dependency node's
     * attached dependencies
     *
     * Returns: the `DNode[]`
     */
    public DNode[] getDeps()
    {
        return this.dependencies;
    }
}


/**
* DNodeGenerator (Next-generation) base
*
* This is a base class for a DNode generator,
* all it requires to construct is:
*
* 1. Context (to know what we are in or so)
* 2. Statements[] (to know what to process)
* 3. TypeChecker (to know how to resolve names)
*
*/
public class DNodeGeneratorBase
{
    /* Type checker (for name lookups) */
    private TypeChecker tc;

    /* Statements to process */
    private Statement[] statements;

    /* Information about our current container for said statements (and initscope) */
    private Context context;

    this(TypeChecker tc, Statement[] statements, Context context)
    {
        this.tc = tc;
        this.statements = statements;
        this.context = context;
    }
}






public final class DFunctionInnerGenerator : DNodeGenerator
{
    private Function func;

    this(TypeChecker tc, IPoolManager poolManager, IFuncDefStore funcDefStore, Function func)
    {
        super(tc, poolManager, funcDefStore);
        this.func = func;
    }

    public override DNode generate()
    {
        /* Recurse downwards */
        /* FIXME: We need to no use modulle, but use some fsort of Function Container */
        Context context = new Context(func, InitScope.STATIC);
        DNode funcDNode = generalPass(func, context);

        return funcDNode;
    }
}


public class DNodeGenerator
{
    /**
    * Type checking utilities
    */
    private TypeChecker tc;
    private Resolver resolver;

    /** 
     * Management of function
     * definitions
     */
    private IFuncDefStore funcDefStore;

    /** 
     * Dependency node pooling
     * management
     */
    private IPoolManager poolManager;

    this(TypeChecker tc, IPoolManager poolManager, IFuncDefStore funcDefStore)
    {
        this.tc = tc;
        this.poolManager = poolManager;
        this.funcDefStore = funcDefStore;
        this.resolver = tc.getResolver();
    }

    /** 
     * Crashes the dependency generator with an
     * expectation message by throwing a new
     * `DependencyException`.
     *
     * Params:
     *   message = the expectation message
     */
    public void expect(string message)
    {
        throw new DependencyException(DependencyError.GENERAL_ERROR, message);
    }

    /** 
     * Performs an access check to the given
     * entity but from the accessing-environment
     * of the provided statement
     *
     * Params:
     *   stmtCtx = the `Statement` to derive the
     * access environment from
     *   referent = the `Entity` being referred
     * to
     *   ignoreAccessModifiers = is we should
     * ignore this check entirely (default: `false`)
     * Returns: `true` if allowed, `false`
     * otherwise
     */
    private bool accessCheck
    (
        Statement stmtCtx, Entity referent,
        bool ignoreAccessModifiers = false
    )
    {
        // If ignoring mode then always allow accesses
        if(ignoreAccessModifiers)
        {
            return true;
        }

        // Container of the accessing-environment
        Container accCntnr = stmtCtx.parentOf();

        // Container of the referent
        Container refCntnr = referent.parentOf();

        // If they are in the same container (exactly)
        // then access should be allowed, irrespective
        // of access modifiers
        if(refCntnr == accCntnr)
        {
            return true;
        }
        // If the accessing-environment is in
        // a container that is descendant
        // of that of the referent's,
        // in such a case access modifiers
        // TOO can be ignored
        else if(resolver.isDescendant(refCntnr, cast(Entity)accCntnr))
        {
            return true;
        }
        // If not, then base the check on access modifiers
        else
        {
            // Obtain the access modifier of the referent
            AccessorType accMod = referent.getAccessorType();

            return referent.getAccessorType() == AccessorType.PUBLIC;
        }
    }

    /** 
     * Throws an exception if there
     * would be an access violation
     * performing the given access
     *
     * See_Also: `accessCheck`
     */
    private void accessCheckAuto
    (
        Statement stmtCtx, Entity referent,
        bool ignoreAccessModifiers = false
    )
    {
        if(accessCheck(stmtCtx, referent, ignoreAccessModifiers))
        {
            DEBUG("Access check passed for accEnv: ", stmtCtx, " with referentEnt: ", referent);
        }
        else
        {
            DEBUG("Access check FAILED for accEnv: ", stmtCtx, " with referentEnt: ", referent);
            throw new AccessViolation(stmtCtx, referent);
        }
    }

    public DNode root;


    public DNode generate()
    {
        DNode[] moduleDNodes;

        Module[] modules = tc.getProgram().getModules();
        foreach(Module curMod; modules)
        {
            /* Start at the top-level container, the module */
            Module modulle = curMod;

            /* Recurse downwards */
            Context context = new Context(modulle, InitScope.STATIC);
            DNode moduleDNode = generalPass(modulle, context);
            
            /* Set nice name */
            moduleDNode.forceName(format("Module (name: %s)", modulle.getName()));

            /* Tack on */
            moduleDNodes ~= moduleDNode;
        }

        

        /* Print tree */
        // gprintln("\n"~moduleDNode.print());

        // FIXME: Ensure that this never crashes
        // FIXME: See how we will process this
        // on the other side
        import tlang.compiler.typecheck.dependency.prog : ProgramDepNode;
        DNode programDNode = new ProgramDepNode(tc.getProgram());
        foreach(m; moduleDNodes)
        {
            programDNode.needs(m);
        }
        
        return programDNode; // TODO: Fix me, make it all or something
    }

    private DNode pool(Statement entity)
    {
        return this.poolManager.pool(entity);
    }

    /**
    * Templatised pooling mechanism
    *
    * Give the node type and entity type (required as not all take in Statement)
    */
    private DNodeType poolT(DNodeType, EntityType)(EntityType entity)
    {
        static if(__traits(isSame, DNodeType, ExpressionDNode))
        {
            return this.poolManager.poolExpression(cast(Expression)entity);
        }
        else static if(__traits(isSame, DNodeType, VariableNode))
        {
            return this.poolManager.poolVariable(cast(Variable)entity);
        }
        else static if(__traits(isSame, DNodeType, StaticVariableDeclaration))
        {
            return this.poolManager.poolStaticVariable(cast(Variable)entity);
        }
        else static if(__traits(isSame, DNodeType, FuncDecNode))
        {
            return this.poolManager.poolFuncDec(cast(Function)entity);
        }
        else
        {
            pragma(msg, "This is an invalid case");
            static assert(false);
        }
    }


    
    
    import tlang.compiler.typecheck.dependency.expression;
    import tlang.compiler.typecheck.dependency.classes.classObject;
    import tlang.compiler.typecheck.dependency.classes.classVirtualInit;

    /* TODO: As mentioned in classObject.d we should static init the class type here */
    private ClassVirtualInit virtualInit(Clazz clazz)
    {
        /* TODO: Pass over variables but we need own pool as instance variable a, must be unique per object */
        
        /* TODO: COnstructor dependency, implicit super, climb class virtual hierachy */

        /* TODO: Constructor run remainders */

        /* TODO: Init classes, vars (check order) */



        return null;
    }

    private ObjectInitializationNode objectInitialize(Clazz clazz, NewExpression newExpression)
    {
        /* We don't pool anything here - a constructor call is unique */
        
        ObjectInitializationNode node = new ObjectInitializationNode(clazz, newExpression);


        /* TODO: Call a virtual pass over the class */

        return node;
    }


    /**
    * Used for maintaining dependencies along a trail of `x.y.z`
    */
    private DNode[][string] pathTrailDeps;
    private void addToPathTrail(string finalEntityName, DNode dep)
    {
        bool found = false;
        foreach(string entityName; pathTrailDeps.keys)
        {
            if(cmp(entityName, finalEntityName) == 0)
            {
                found = true;
                break;
            }
        }

        if(found == false)
        {
            pathTrailDeps[finalEntityName] = [];
        }
        
        pathTrailDeps[finalEntityName] ~= dep;
        
    }


    private DNode expressionPass(Expression exp, Context context)
    {
        ExpressionDNode dnode = poolT!(ExpressionDNode, Expression)(exp);

        WARN("expressionPass(Exp): Processing "~exp.toString());
        DEBUG("expressionPass(Exp): Context coming in "~to!(string)(context));

        /* TODO: Add pooling */

        /**
        * Number literal
        */
        if(cast(NumberLiteral)exp)
        {
            /* TODO: Make number LiteralNode */
            return dnode;
        }
        /**
        * Function calls (and struct constrctors)
        */
        else if (cast(FunctionCall)exp)
        {
            /* TODO: Implement argument expression dependency */
            FunctionCall funcCall = cast(FunctionCall)exp;
            DEBUG("FuncCall: "~funcCall.getName());

            /* TODO: We need to fetch the cached function definition here and call it */
            Entity funcEntity = resolver.resolveBest(context.container, funcCall.getName());
            assert(funcEntity);

            // Access check
            accessCheckAuto(exp, funcEntity);
            
            // FIXME: The below is failing (we probably need a forward look ahead?)
            // OR use the addFuncDef list?
            //WAIT! We don't need a funcDefNode actually. No, we lierally do not.
            //Remmeber, they are done in a seperate pass, what we need is just our FUncCall DNode
            // WHICH we have below as `dnode`!!!!
            // DNode funcDefDNode = retrieveFunctionDefinitionNode(tc.getResolver().generateName(tc.getModule(), funcEntity));
            // gprintln("FuncCall (FuncDefNode): "~to!(string)(funcDefDNode));
            // dnode.needs(funcDefDNode); /* NOTE: New code as of 4th October 2022 */

            //NOTE: Check if we need to set a context here to that of the context we occuring in
            funcCall.context = context;


            /**
            * Go through each argument generating a fresh DNode for each expression
            */
            foreach(Expression actualArgument; funcCall.getCallArguments())
            {
                ExpressionDNode actualArgumentDNode = poolT!(ExpressionDNode, Expression)(actualArgument);
                // dnode.needs(actualArgumentDNode);

                // gprintln("We need to add recursion here", DebugType.ERROR);
                // gprintln("Func?: "~to!(string)(cast(FunctionCall)actualArgument));
                // gprintln("Literal?: "~to!(string)(cast(NumberLiteral)actualArgument));
                // gprintln("Hello baba", DebugType.ERROR);

                /* TODO: Ensure the correct context */
                dnode.needs(expressionPass(actualArgument, context));
            }
        }
        /**
        * `new A()` expression
        */
        else if(cast(NewExpression)exp)
        {
            /* The NewExpression */
            NewExpression newExpression = cast(NewExpression)exp;

            /* Get the FunctionCall */
            FunctionCall constructorCall = newExpression.getFuncCall();

            /* Get the name of the class the function call referes to */
            string className = constructorCall.getName();
            Type type = tc.getType(context.container, className);

            if(type)
            {
                Clazz clazz = cast(Clazz)type;

                if(clazz)
                {
                    /* TODO: Process class static initialization */
                    /* Get the static class dependency */
                    ClassStaticNode classDependency = classPassStatic(clazz);

                    /* Make this expression depend on static initalization of the class */
                    dnode.needs(classDependency);

                    /* TODO: Process object initialization */
                    ObjectInitializationNode objectDependency = objectInitialize(clazz, newExpression);
                    dnode.needs(objectDependency);

                    /* TODO: Process function call argument */
                }
                else
                {
                    expect("Only class-type may be used with `new`");
                    assert(false);
                }
                DEBUG("King of the castle");
            }
            else
            {
                expect("Invalid ryp");
                assert(false);
            }
            // FunctionCall 
        }
        /**
        * Variable expression
        *
        * Example: `p`, `p.p.l`
        *
        * First example, `p`, would have expressionNode.needs(AccessNode)
        * Second example, `p.p.l`, would have expressionNode.needs(AccessNode.needs(AccessNode.needs(AccessNode)))
        */
        else if(cast(VariableExpression)exp)
        {
            // Extract the variable's name
            VariableExpression varExp = cast(VariableExpression)exp;
            string nearestName = varExp.getName();

            // Set the context of the variable expression
            varExp.setContext(context);
           
            // Resolve the entity the name refers to
            Entity namedEntity = tc.getResolver().resolveBest(context.getContainer(), nearestName);


            /* If the entity was found */
            if(namedEntity)
            {
                /* FIXME: Below assumes basic variable declarations at module level, fix later */

                // Access check
                accessCheckAuto(exp, namedEntity);

                /** 
                 * If `namedEntity` is a `Variable`
                 *
                 * Think of, well, a variable
                 */
                if(cast(Variable)namedEntity)
                {
                    /* Get the entity as a Variable */
                    Variable variable = cast(Variable)namedEntity;

                    /* Variable reference count must increase */
                    tc.touch(variable);

                    /* Pool the node */
                    VariableNode varDecNode = poolT!(VariableNode, Variable)(variable);

                    /**
                     * Check if the variable being referenced has been
                     * visited (i.e. declared)
                     *
                     * If it has then setup dependency, if not then error
                     * out
                     */
                    if(varDecNode.isVisisted())
                    {
                        dnode.needs(varDecNode);
                    }
                    else
                    {
                        expect("Cannot reference variable "~nearestName~" which exists but has not been declared yet");
                    }
                }
                /** 
                 * If `namedEntity` is a `Function`
                 *
                 * Think of a function handle
                 */
                else if(cast(Function)namedEntity)
                {
                    /**
                    * FIXME: Yes it isn't a funcall not, and it is not a variable and is probably
                    * being returned as the lookup, so a FUnction node i guess 
                    */
                    Function funcHandle = cast(Function)namedEntity;
                    
                    /**
                    * FIXME: Find the best place for this. Functions will always
                    * be declared (atleast for basic examples as like now) in
                    * the module level
                    */
                    Context cont = new Context(tc.getResolver().findContainerOfType(Module.classinfo, funcHandle), InitScope.STATIC);
                    // cont.container = tc.getModule();
                    // cont.
                    funcHandle.setContext(cont);

                    // funcHandle
                    

                    /**
                    * FIXME: Do we have to visit the function, I am not sure, like maybe declaration
                    * or surely it is already declared??!?!?
                    *
                    * Does pooling it make sense? Do we force a visitation?
                    */
                    FuncDecNode funcDecNode = poolT!(FuncDecNode, Function)(funcHandle);
                    dnode.needs(funcDecNode);

                    WARN("Muh function handle: "~namedEntity.toString());
                }
                else
                {
                    /* TODO: Add check ? */
                }   
            }
            /* If the entity could not be found */
            else
            {
                expect("No entity by the name "~nearestName~" exists (at all)");
            }
        }
        /**
        * Binary operator
        */
        else if(cast(BinaryOperatorExpression)exp)
        {
            /* Get the binary operator expression */
            BinaryOperatorExpression binOp = cast(BinaryOperatorExpression)exp;

            

            /**
            * If the operator is a dot operator
            *
            * We then treat that as an accessor
            *
            * Example: func().p1
            * Example: new A().p1
            */
            if(binOp.getOperator() == SymbolType.DOT)
            {
                /**
                * Get the left-node (the thing being accessed)
                *
                * Either a `new A()`, `A()`
                */
                Expression leftExp = binOp.getLeftExpression();
                

                /**
                * Process the right-hand side expression
                * but we should give it the Context that
                * it is accessing some sort of class for example
                * such that resolution can work properly
                * (hence the need for `Context` in this function)
                *
                * 1. The Container is the type of the object and
                * we then call expresssionPass on it which
                * will eensure static init of class type etc
                */

                /* The NewExpression */
                NewExpression newExpression = cast(NewExpression)leftExp;

                /* Get the FunctionCall */
                FunctionCall constructorCall = newExpression.getFuncCall();

                /* Get the name of the class the function call referes to */
                string className = constructorCall.getName();
                Type type = tc.getType(context.container, className);

                Clazz clazzType = cast(Clazz)type;
                Container clazzContainer = cast(Container)clazzType;



                
                Context objectContext = new Context(clazzContainer, InitScope.VIRTUAL);
                /* Also, only resolve within */
                objectContext.noAllowUp();


                /**
                * Pass the newExpression and static init the class
                * using current context
                *
                * We now know the class is static inited, and also
                * the object
                */
                DNode lhsNode = expressionPass(leftExp, context);

                /**
                * Now using this pass the right-hand side with context
                * being that the object access has virtual (static and
                * non-static access as it is, well, an object `new A()`)
                *
                * Context being eithin the object and its class
                */
                DNode rhsNode = expressionPass(binOp.getRightExpression(), objectContext);
                

                // if(cast(NewExpression)leftExp)

                /**
                * TODO
                *
                * 1. Split up and recurse down the path (rhsExpression)
                * 2. Above is done already in varExp (well needs to be implemented)
                * 3. Make the rhsNode finanly depend on lhsNode
                * 4. dnode (whole expression, dot operator expresiosn) relies on rhsNode
                *
                */
                dnode.needs(lhsNode);
                lhsNode.needs(rhsNode);
                

                
            }
            /**
            * Anything else are mutually exlsuive (i.e. not chained)
            *
            * FIXME: For now
            */
            else
            {
                /* Process left and right */
                DNode leftNode = expressionPass(binOp.getLeftExpression(), context);
                DNode rightNode = expressionPass(binOp.getRightExpression(), context);

                /* Require the evaluation of these */
                /* TODO: Add specific DNode type dependent on the type of operator */
                dnode.needs(leftNode);
                dnode.needs(rightNode);
            }
        }
        /**
        * Unary operator
        */
        else if(cast(UnaryOperatorExpression)exp)
        {
            /* Get the unary operator expression */
            UnaryOperatorExpression unaryOp = cast(UnaryOperatorExpression)exp;

            /* Process the expression */
            DNode expressionNode = expressionPass(unaryOp.getExpression(), context);
                

            /* Require the evaluation of the expression */
            /* TODO: Add specific DNode type dependent on the type of operator */
            dnode.needs(expressionNode);
        }
        /**
        * Type cast operator (CastedExpression)
        */
        else if(cast(CastedExpression)exp)
        {
            CastedExpression castedExpression = cast(CastedExpression)exp;

            // Set the context as we need to grab it later in the typechecker
            castedExpression.context = context;

            /* Extract the embedded expression and pass it */
            Expression uncastedExpression = castedExpression.getEmbeddedExpression();
            DNode uncastedExpressionDNode = expressionPass(uncastedExpression, context);

            dnode.needs(uncastedExpressionDNode);
        }
        /**
        * Array indexing (ArrayIndex)
        */
        else if(cast(ArrayIndex)exp)
        {
            ArrayIndex arrayIndex = cast(ArrayIndex)exp;

            // Set the context as we need to grab it later in the typechecker
            arrayIndex.context = context;

            /* The index's expression */
            Expression indexExp = arrayIndex.getIndex();
            DNode indexExpDNode = expressionPass(indexExp, context);
            dnode.needs(indexExpDNode);

            /* The thing being indexeds' expression */
            Expression indexedExp = arrayIndex.getIndexed();
            DNode indexedExpDNode = expressionPass(indexedExp, context);
            dnode.needs(indexedExpDNode);
        }
        else
        {
            // dnode = new DNode(this, exp);



            // dnode.needs()
            ERROR("Interesting");
        }
        



        return dnode;
    }


    import tlang.compiler.typecheck.dependency.variables;
    private ModuleVariableDeclaration pool_module_vardec(Variable entity)
    {
        return this.poolManager.poolModuleVariableDeclaration(entity);
    }

    // TODO: Work in progress
    private DNode generalStatement(Container c, Context context, Statement entity)
    {
        // /* Pool the container as `node` */
        // Entity namedContainer = cast(Entity)c;
        // assert(namedContainer);
        // DNode node = pool(namedContainer);






        /**
        * Variable paremeters (for functions)
        */
        if(cast(VariableParameter)entity)
        {
            VariableParameter varParamDec = cast(VariableParameter)entity;

            // Set context
            entity.setContext(context);

            // Pool and mark as visited
            // NOTE: I guess for now use VariableDNode as that is what is used in expressionPass
            // with the poolT! constrcutor, doing otherwise causes a cast failure and hence
            // null: /git/tlang/tlang/issues/52#issuecomment-325
            DNode dnode = poolT!(VariableNode, Variable)(varParamDec);
            dnode.markVisited();

            return null;
        }
        /**
        * Variable declarations
        */
        else if(cast(Variable)entity)
        {
            /* Get the Variable and information */
            Variable variable = cast(Variable)entity;

                /* TODO: 25Oct new */
            // Context d = new Context( cast(Container)modulle, InitScope.STATIC);
            entity.setContext(context);
            /* TODO: Above 25oct new */

            Type variableType = tc.getType(c, variable.getType());
            assert(variableType); /* TODO: Handle invalid variable type */
            DNode variableDNode = poolT!(StaticVariableDeclaration, Variable)(variable);
            writeln("Hello");
            writeln("VarType: "~to!(string)(variableType));

            /* Add an entry to the reference counting map */
            tc.touch(variable);

            /* Basic type */
            if(cast(Primitive)variableType)
            {
                /* Do nothing */
            }
            /* Class-type */
            else if(cast(Clazz)variableType)
            {
                writeln("Literally hello");
                
                /* Get the static class dependency */
                ClassStaticNode classDependency = classPassStatic(cast(Clazz)variableType);

                /* Make this variable declaration depend on static initalization of the class */
                variableDNode.needs(classDependency);
            }
            /* Struct-type */
            else if(cast(Struct)variableType)
            {

            }
            /* Stack-based array-type */
            else if(cast(StackArray)variableType)
            {
                // TODO: For array support not all too sure what I shoudl put here, perhap nothing?
                StackArray arrayType = cast(StackArray)variableType;

                // TODO: We might need to do pointer magic

                // (TODO) Check component type
                Type componentType = arrayType.getComponentType();

                // If the component type is a primitive type
                if(cast(Primitive)componentType)
                {
                    /* Do nothing (I presume?) */
                }
                // If not
                else
                {
                    // TODO: Add more advanced handling here
                    ERROR("Advanced component types l;ike arrays of arrays or arrays of classes etc not yet supported");
                    assert(false);
                }

                ERROR("Arrays (and these are stack arrays) are not yet supported");
                // assert(false);
            }
            /* Anything else */
            else
            {
                /* This should never happen */
                DEBUG(variableType);
                DEBUG(variableType.classinfo);
                ERROR("#ThisShouldNeverHappen Fault: A variable declaration with a kind-of type we don't know");
                assert(false);
            }


            /* Set as visited */
            variableDNode.markVisited();

            /* If there is an assignment attached to this */
            if(variable.getAssignment())
            {
                /* Extract the assignment */
                VariableAssignment varAssign = variable.getAssignment();

                /* Set the Context of the assignment to the current context */
                varAssign.setContext(context);

                /* Pool the assignment to get a DNode */
                DNode expressionNode = expressionPass(varAssign.getExpression(), context);

                /* The variable declaration is dependant on the assigne expression */
                variableDNode.needs(expressionNode);
            }

            /* The current container is dependent on this variable declaration */
            // node.needs(variableDNode);
            return variableDNode;
        }
        /**
        * Variable asignments
        */
        else if(cast(VariableAssignmentStdAlone)entity)
        {
            VariableAssignmentStdAlone vAsStdAl = cast(VariableAssignmentStdAlone)entity;
            vAsStdAl.setContext(context);

            /* TODO: CHeck avriable name even */
            DEBUG("YEAST ENJOYER");


            // FIXME: The below assert fails for function definitions trying to refer to global values
            // as a reoslveBest (up) is needed. We should firstly check if within fails, if so,
            // resolveBest, if that fails, then it is an error (see #46)
            assert(tc.getResolver().resolveBest(c, vAsStdAl.getVariableName()));
            DEBUG("YEAST ENJOYER");
            Variable variable = cast(Variable)tc.getResolver().resolveBest(c, vAsStdAl.getVariableName());
            assert(variable);

            /* Assinging to a variable is usage, therefore increment the reference count */
            tc.touch(variable);


            /* Pool the variable */
            DNode varDecDNode = pool(variable);

            /* TODO: Make sure a DNode exists (implying it's been declared already) */
            if(varDecDNode.isVisisted())
            {
                /* Pool varass stdalone */
                DNode vStdAlDNode = pool(vAsStdAl);

                /* Pool the expression and make the vAStdAlDNode depend on it */
                DNode expression = expressionPass(vAsStdAl.getExpression(), context);
                vStdAlDNode.needs(expression);

                return vStdAlDNode;
            }
            else
            {
                expect("Cannot reference variable "~vAsStdAl.getVariableName()~" which exists but has not been declared yet");
                return null;
            }            
        }
        /**
        * Array assignments
        */
        else if(cast(ArrayAssignment)entity)
        {
            ArrayAssignment arrayAssignment = cast(ArrayAssignment)entity;
            arrayAssignment.setContext(context);
            DNode arrayAssDerefDNode = pool(arrayAssignment);

            /* Pass the expression to be assigned */
            Expression assignedExpression = arrayAssignment.getAssignmentExpression();
            DNode assignmentExpressionDNode = expressionPass(assignedExpression, context);
            arrayAssDerefDNode.needs(assignmentExpressionDNode);

            /**
            * Extract the ArrayIndex expression
            *
            * This consists of two parts (e.g. `myArray[i]`):
            *
            * 1. The indexTo `myArray`
            * 2. The index `i`
            */
            ArrayIndex arrayIndexExpression = arrayAssignment.getArrayLeft();
            Expression indexTo = arrayIndexExpression.getIndexed();
            Expression index = arrayIndexExpression.getIndex();

            DNode indexToExpression = expressionPass(indexTo, context);
            arrayAssDerefDNode.needs(indexToExpression);

            DNode indexExpression = expressionPass(index, context);
            arrayAssDerefDNode.needs(indexExpression);
            



            ERROR("Please implement array assignment dependency generation");
            // assert(false);

            return arrayAssDerefDNode;
        }
        /**
        * Function definitions
        */
        else if(cast(Function)entity)
        {
            /* Grab the function */
            Function func = cast(Function)entity;

            /* Don't forget to set its context */
            func.context = context;

            /* Add funtion definition */
            DEBUG("Hello"); // TODO: Check `root`, just use findContainerOfType
            // Module owner = cast(Module)tc.getResolver().findContainerOfType(Module.classinfo, func));
            this.funcDefStore.addFunctionDef(cast(Module)root.entity, func);

            return null;
        }
        /**
        * Return statement
        */
        else if(cast(ReturnStmt)entity)
        {
            ReturnStmt returnStatement = cast(ReturnStmt)entity;
            returnStatement.setContext(context);

            DNode returnStatementDNode = pool(returnStatement);

            /* Check if this return statement has an expression attached */
            if(returnStatement.hasReturnExpression())
            {
                /* Process the return expression */
                Expression returnExpression = returnStatement.getReturnExpression();
                DNode returnExpressionDNode = expressionPass(returnExpression, context);

                /* Make return depend on the return expression */
                returnStatementDNode.needs(returnExpressionDNode);
            }

            /* Make this container depend on this return statement */
            // node.needs(returnStatementDNode);
            return returnStatementDNode;
        }
        /**
        * If statements
        */
        else if(cast(IfStatement)entity)
        {
            IfStatement ifStatement = cast(IfStatement)entity;
            ifStatement.setContext(context);
            DNode ifStatementDNode = pool(ifStatement);

            /* Add each branch as a dependency */
            foreach(Branch branch; ifStatement.getBranches())
            {
                DNode branchDNode = pool(branch);
                // Set context of branch (it is parented by the IfStmt)
                // NOTE: This is dead code as the above is done by Parser and
                // we need not set context here, only matters at the generalPass
                // call later (context being passed in) as a starting point
                branch.setContext(new Context(ifStatement, context.initScope));

                // Extract the potential branch condition
                Expression branchCondition = branch.getCondition();

                // Check if this branch has a condition
                if(!(branchCondition is null))
                {
                    // We use container of IfStmt and nt IfStmt otself as nothing can really be
                    // contained in it that the condition expression would be able to lookup
                    DNode branchConditionDNode = expressionPass(branchCondition, context);
                    branchDNode.needs(branchConditionDNode);
                }

                DEBUG("branch parentOf(): "~to!(string)(branch.parentOf()));
                assert(branch.parentOf());
                DEBUG("branch generalPass(context="~to!(string)(context.getContainer())~")");

                // When generalPass()'ing a branch's body we don't want to pass in `context`
                // as that is containing the branch container and hence we skip anything IN the
                // branch container
                // NOTE: Check initScope
                Context branchContext = new Context(branch, context.initScope);
                DNode branchStatementsDNode = generalPass(branch, branchContext);
                branchDNode.needs(branchStatementsDNode);

                /* Make the if statement depend on this branch */
                ifStatementDNode.needs(branchDNode);
            }

            /* Make this container depend on this if statement */
            // node.needs(ifStatementDNode);
            return ifStatementDNode;
        }
        /**
        * While loops
        */
        else if(cast(WhileLoop)entity)
        {
            WhileLoop whileLoopStmt = cast(WhileLoop)entity;
            whileLoopStmt.setContext(context);
            DNode whileLoopDNode = pool(whileLoopStmt);

            // Extract the branch (body Statement[] + condition)
            Branch whileBranch = whileLoopStmt.getBranch();
            DNode branchDNode = pool(whileBranch);
            DEBUG("Branch: "~to!(string)(whileBranch));

            // If this is a while-loop
            if(!whileLoopStmt.isDoWhile)
            {
                // Extract the condition
                Expression branchCondition = whileBranch.getCondition();

                // Pass the expression
                DNode branchConditionDNode = expressionPass(branchCondition, context);

                // Make the branch dependent on this expression's evaluation
                branchDNode.needs(branchConditionDNode);

                
                // Now pass over the statements in the branch's body
                Context branchContext = new Context(whileBranch, InitScope.STATIC);
                DNode branchBodyDNode = generalPass(whileBranch, branchContext);

                // Finally make the branchDNode depend on the body dnode (above)
                branchDNode.needs(branchBodyDNode);
            }
            // If this is a do-while loop
            // TODO: I don't think we really need to reverse this?
            // Logically we should, but the typechecker will add this things in the correct order anyways?
            // We need to look into this!
            // Our nodes at the back will always be placed at the back, and the expression will end ip upfront
            // i think it is a problem oif maybe other expressions are left on the stack but is that ever a problem
            //now with the statement <-> instruction mapping (like will that ever even occur?)
            else
            {
                // Pass over the statements in the branch's body
                Context branchContext = new Context(whileBranch, InitScope.STATIC);
                DNode branchBodyDNode = generalPass(whileBranch, branchContext);

                // Make the branchDNode depend on the body dnode (above)
                branchDNode.needs(branchBodyDNode);


                // Extract the condition
                Expression branchCondition = whileBranch.getCondition();

                // Pass the expression
                DNode branchConditionDNode = expressionPass(branchCondition, context);

                // Make the branch dependent on this expression's evaluation
                branchDNode.needs(branchConditionDNode);
            }

            /* Make the while-loop/do-while loop depend on the branchDNode */
            whileLoopDNode.needs(branchDNode);

            /* Make the node of this generalPass we are in depend on the whileLoop's DNode */
            // node.needs(whileLoopDNode);
            return whileLoopDNode;
        }
        /**
        * For loops
        */
        else if(cast(ForLoop)entity)
        {
            ForLoop forLoop = cast(ForLoop)entity;
            forLoop.setContext(context);
            DNode forLoopDNode = pool(forLoop);


            // Check for a pre-run statement
            if(forLoop.hasPreRunStatement())
            {
                Statement preRunStatement = forLoop.getPreRunStatement();
                DNode preRunStatementDNode = generalStatement(c, context, preRunStatement);
                forLoopDNode.needs(preRunStatementDNode);
            }

            // Get the branch
            Branch forLoopBranch = forLoop.getBranch();
            Expression forLoopCondition = forLoopBranch.getCondition();

            // TODO: The below context won't work until we make the `preLoopStatement` (and maybe `postIterationStatement`??)
            // a part of the body of the for-loop (see issue #78)
            // Pass over the condition expression
            DNode forLoopConditionDNode = expressionPass(forLoopCondition, new Context(forLoop, InitScope.STATIC));
            forLoopDNode.needs(forLoopConditionDNode);


            // TODO: What we need here now is effectively the equivalent of the Parser's `parseStatement()`
            // (i.e. for a single statement), so this body of code should be `generalStatement(Container, Context, Statement)`
            // and should be called within this loop

            // We want to generalPass the Branch Container and the context if within the Branch container
            DNode branchDNode = generalPass(forLoopBranch, new Context(forLoopBranch, InitScope.STATIC));
            forLoopDNode.needs(branchDNode);

            return forLoopDNode;
        }
        /**
        * Pointer dereference assigmnets (PointerDereferenceAssignment)
        */
        else if(cast(PointerDereferenceAssignment)entity)
        {
            PointerDereferenceAssignment ptrAssDeref = cast(PointerDereferenceAssignment)entity;
            ptrAssDeref.setContext(context);
            DNode ptrAssDerefDNode = pool(ptrAssDeref);

            /* Pass the expression being assigned */
            Expression assignmentExpression = ptrAssDeref.getExpression();
            DNode assignmentExpressionDNode = expressionPass(assignmentExpression, context);
            ptrAssDerefDNode.needs(assignmentExpressionDNode);

            /* Pass the pointer expression */
            Expression pointerExpression = ptrAssDeref.getPointerExpression();
            DNode pointerExpressionDNode = expressionPass(pointerExpression, context);
            ptrAssDerefDNode.needs(pointerExpressionDNode);

            return ptrAssDerefDNode;
        }
        /**
        * Discard statement (DiscardStatement)
        */
        else if(cast(DiscardStatement)entity)
        {
            DiscardStatement discardStatement = cast(DiscardStatement)entity;
            discardStatement.setContext(context);
            DNode discardStatementDNode = pool(discardStatement);

            ERROR("Implement discard statement!");
            
            /* Pass the expression */
            Expression discardExpression = discardStatement.getExpression();
            DNode discardExpresionDNode = expressionPass(discardExpression, context);
            discardStatementDNode.needs(discardExpresionDNode);


            return discardStatementDNode;
        }
        /**
        * Extern statement (ExternStmt)
        */
        else if(cast(ExternStmt)entity)
        {
            /* We don't do anything, this is to be handled in typechecker pre-run */    
            /* NOTE: If anything we ought to remove these ExternSTmt nodes during such a process */
            return null;
        }
        /** 
         * Function call (statement-level)
         */
        else if(cast(FunctionCall)entity)
        {
            FunctionCall funcCall = cast(FunctionCall)entity;
            funcCall.setContext(context);
            
            // It MUST be if we are processing it in `generalPass()`
            assert(funcCall.isStatementLevelFuncCall());
            INFO("Function calls (at statement level)");

            // The FunctionCall is an expression, so to get a DNode from it `expressionPass()` it
            DNode funcCallDNode = expressionPass(funcCall, context);

            return funcCallDNode;
        }

        return null;
    }

    /** 
     * Performs a general pass over the Statement(s) in the given container
     * and with the given Context
     *
     * Params:
     *   c = the Container on which to pass through all of its elements
     *   context = the Context to use for the pass
     *
     * Returns: a DNode for the Container c
     */
    private DNode generalPass(Container c, Context context)
    {
        Entity namedContainer = cast(Entity)c;
        assert(namedContainer);

        DNode node = pool(namedContainer);

        /* FIXME: Fix this later, currently using it for Function definitions */
        bool ignoreInitScope = true;

        /* If this is a Module then it must become the root */
        if(cast(Module)namedContainer)
        {
            root = node;
        }
        /* NOTE: 1st October: Just for now ignore funciton stuff InitScvope? */
        else if(cast(Function)namedContainer)
        {
            ignoreInitScope=false;
            root=pool(cast(Module)tc.getResolver().findContainerOfType(Module.classinfo, namedContainer));
        }


        /**
        * Get the statements of this Container
        */
        Statement[] entities;
        foreach(Statement statement; c.getStatements())
        {
            if(!(statement is null))
            {
                entities ~= cast(Statement)statement;
            }
        }

        /**
        * Process each Entity
        *
        * TODO: Non entities later
        */
        foreach(Statement entity; entities)
        {
            DEBUG("generalPass(): Processing entity: "~entity.toString());

            Entity ent = cast(Entity)entity;
            // NOTE: COme back to and re-enable when this makes sense (IF it even needs to be here)
            // if(ent && ent.getModifierType() != InitScope.STATIC && ignoreInitScope)
            // {
            //     writeln("Did we just skip someone?");
            //     writeln("InitScope: "~to!(string)(ent.getModifierType()));
            //     writeln(ent);
            //     //TODO: Come back to this and check it!!!!! Maybe this can be removed!
            //     continue;
            // }

            DNode statementDNode = generalStatement(c, context, entity);
            if(statementDNode is null)
            {
                DEBUG("Not adding dependency '"~to!(string)(statementDNode)~"' as it is null");
            }
            else
            {
                node.needs(statementDNode);
            }
            
        }

        return node;
    }

    import tlang.compiler.typecheck.dependency.classes.classStaticDep;
    private ClassStaticNode poolClassStatic(Clazz clazz)
    {
        /* Sanity check */
        if(clazz.getModifierType() != InitScope.STATIC)
        {
            expect("SanityCheck: poolClassStatic(): Cannot pool a non-static class");
            // assert(clazz.getModifierType() == InitScope.STATIC);
        }
        
        return this.poolManager.poolClassStatic(clazz);
    }

    /**
    * Passes through the given Class to resolve
    * dependencies, creates DNode(s) for them,
    * adds them to a DNode created for the Class
    * given and then returns it
    *
    * This is called for static initialization
    */
    private ClassStaticNode classPassStatic(Clazz clazz)
    {
        /* Get a DNode for the Class */
        ClassStaticNode classDNode = poolClassStatic(clazz);

        DEBUG("classPassStatic(): Static init check for?: "~to!(string)(clazz));

        /* Make sure we are static */
        if(clazz.getModifierType()!=InitScope.STATIC)
        {
            ERROR("classPassStatic(): Not static class");
            assert(false);
        }

        /* Crawl up the static initialization tree of parent static classes */
        if(clazz.parentOf() && cast(Clazz)clazz.parentOf())
        {
            /* Get the dependency node for the parent class */
            ClassStaticNode parentClassDNode = classPassStatic(cast(Clazz)clazz.parentOf());

            /* Make ourselves dependent on its initialization */
            classDNode.needs(parentClassDNode);
        }


        /* TODO: visiation loop prevention */
        /**
        * If we have been visited then return nimmediately
        */
        if(classDNode.isVisisted())
        {
            return classDNode;
        }
        else
        {
            /* Set as visited */
            classDNode.markVisited();
        }

        generalPass(clazz, new Context(clazz, InitScope.STATIC));

        return classDNode;
    }
}