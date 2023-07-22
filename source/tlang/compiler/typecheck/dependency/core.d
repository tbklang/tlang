module tlang.compiler.typecheck.dependency.core;

import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import tlang.compiler.parsing.core;
import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.exceptions;
import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.typing.builtins;
import tlang.compiler.typecheck.dependency.exceptions : DependencyException, DependencyError;


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

    public DNode generate()
    {
        return ownGenerator.generate();
    }
}

/**
* All declared functions
*/
private FunctionData[string] functions;


/**
* Returns the declared functions
*/
public FunctionData[string] grabFunctionDefs()
{
    return functions;
}

/**
* Creates a new FunctionData and adds it to the
* list of declared functions
*
* Requires a TypeChecker `tc`
*/
private void addFunctionDef(TypeChecker tc, Function func)
{
    /* (Sanity Check) This should never be called again */
    foreach(string cFuncKey; functions.keys())
    {
        FunctionData cFuncData = functions[cFuncKey];
        Function cFunc = cFuncData.func;

        if(cFunc == func)
        {
            assert(false);
        }
    }

    /**
    * Create the FunctionData, coupled with it own DNodeGenerator
    * context etc.
    */
    FunctionData funcData;
    funcData.ownGenerator = new DFunctionInnerGenerator(tc, func);
    funcData.name = func.getName();
    funcData.func = func;


    functions[funcData.name] = funcData;


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

    protected DNodeGenerator dnodegen;
    protected Resolver resolver;

    private bool visited;
    private bool complete;
    private DNode[] dependencies;

    this(DNodeGenerator dnodegen, Statement entity)
    {
        this.entity = entity;
        this.dnodegen = dnodegen;
        this.resolver = dnodegen.resolver;

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
        gprintln("Done/Not-done?: "~to!(string)(isDone));

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

    this(TypeChecker tc, Function func)
    {
        super(tc);
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
    public Resolver resolver;


    /**
    * Supporting string -> DNode map for `saveFunctionDefinitionNode`
    * and `retrieveFunctionDefintionNode`
    */
    private DNode[string] functionDefinitions;

    /**
    * Given a DNode generated by a Function (function definition)
    * this will extract the name of the function and save the DNode
    * into the map for later retrieval by `retrieveFunctionDefinitionNode`
    */
    private void saveFunctionDefinitionNode(DNode funcDefNode)
    {
        gprintln("saveFunctionDefinitionNode: Implement me please");

        // Extract the name of the function
        Function functionDefinition = cast(Function)funcDefNode.getEntity();
        assert(functionDefinition);
        string functionNameAbsolutePath = resolver.generateName(cast(Container)root.getEntity(), cast(Entity)functionDefinition);

        // Save to the map
        functionDefinitions[functionNameAbsolutePath] = funcDefNode;
    }

    /**
    * Given the absolute path to a function, this will retrieve the
    * Function (function definition) DNode from the map
    */
    private DNode retrieveFunctionDefinitionNode(string functionAbsolutePath)
    {
        gprintln("retrieveFunctionDefinitionNode: Implement me please");

        // TODO: Add an assertion for failed lookup
        return functionDefinitions[functionAbsolutePath];
    }


    /**
    * DNode pool
    *
    * This holds unique pool entries
    */
    private static DNode[] nodePool;

    this(TypeChecker tc)
    {
        // /* NOTE: NEW STUFF 1st Oct 2022 */
        // Module modulle = tc.getModule();
        // Context context = new Context(modulle, InitScope.STATIC);
        // super(tc, context, context.getContainer().getStatements());




        this.tc = tc;
        this.resolver = tc.getResolver();

        /* TODO: Make this call in the TypeChecker instance */
        //generate();
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

    public DNode root;


    public DNode generate()
    {
        /* Start at the top-level container, the module */
        Module modulle = tc.getModule();

        /* Recurse downwards */
        Context context = new Context(modulle, InitScope.STATIC);
        DNode moduleDNode = generalPass(modulle, context);

        /* Print tree */
        // gprintln("\n"~moduleDNode.print());

        return moduleDNode;
    }

    private DNode pool(Statement entity)
    {
        foreach(DNode dnode; nodePool)
        {
            if(dnode.getEntity() == entity)
            {
                return dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        DNode newDNode = new DNode(this, entity);
        nodePool ~= newDNode;

        return newDNode;
    }

    /**
    * Templatised pooling mechanism
    *
    * Give the node type and entity type (required as not all take in Statement)
    */
    private DNodeType poolT(DNodeType, EntityType)(EntityType entity)
    {
        foreach(DNode dnode; nodePool)
        {
            if(dnode.getEntity() == entity)
            {
                return cast(DNodeType)dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        DNodeType newDNode = new DNodeType(this, entity);
        nodePool ~= newDNode;

        return newDNode;
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
        
        ObjectInitializationNode node = new ObjectInitializationNode(this, clazz, newExpression);


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

        gprintln("expressionPass(Exp): Processing "~exp.toString(), DebugType.WARNING);
        gprintln("expressionPass(Exp): Context coming in "~to!(string)(context));

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
            gprintln("FuncCall: "~funcCall.getName());

            /* TODO: We need to fetch the cached function definition here and call it */
            Entity funcEntity = resolver.resolveBest(context.container, funcCall.getName());
            assert(funcEntity);
            
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
                gprintln("Poe naais");
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
            /* TODO: Figure out where the variable lies */

            /* TODO: Change this later */
            // return new DNode(this, exp);

            /**
            * Extract the variable name
            */
            VariableExpression varExp = cast(VariableExpression)exp;
            
            string path = varExp.getName();
            long nearestDot = indexOf(path, ".");


            gprintln("VariableExpressionPass(): Path: "~path, DebugType.WARNING);
            gprintln("VarExp Context set? (before): "~to!(string)(varExp.getContext()));

            /* See issue #9 on Gitea */
            /* FIXME: We only set context in some situations - we MUST fix this */
            /* NOTE: I think THIS is wrong -   varExp.setContext(context); */
            /* What we need to do is set the variable itself me thinks */
            /* NOTE: But the above seems to also be needed */

            /* FIXME: Remove the context sets below */

            /* NOTE: Fix is below I think (it doesn't crash then) */
            /* Set context for expression and the variable itself */
            varExp.setContext(context);
            gprintln("Context (after): "~to!(string)(varExp.getContext().getContainer()));
            Entity bruh = tc.getResolver().resolveBest(context.getContainer(), path);
            bruh.setContext(context);
          
            /* Has two dots? */
            bool hasTwoDots = indexOf(path, ".", nearestDot+1) == lastIndexOf(path, ".") && indexOf(path, ".", nearestDot+1) > -1;
            gprintln(indexOf(path, ".", nearestDot+1));

            /**
            * Current named entity
            */
            string nearestName;

            /**
            * If the `path` has no dots
            *
            * Example: `variableX`
            */
            if(nearestDot == -1)
            {
                /* The name is exactly the path */
                nearestName = path;

                /* Resolve the Entity */
                Entity namedEntity = tc.getResolver().resolveBest(context.getContainer(), nearestName);



                 /**
                * NEW CODE!!!! (Added 25th Oct)
                *
                * Update name for later typechecking resolution of var
                * 
                */
                varExp.setContext(context);
                gprintln("Kont: "~to!(string)(context));

                
                if(namedEntity)
                {
                    /* FIXME: Below assumes basic variable declarations at module level, fix later */

                    /**
                    * Get the Entity as a Variable
                    */
                    Variable variable = cast(Variable)namedEntity;

                    if(variable)
                    {
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


                        /* Use the Context to make a decision */
                    }
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
                        Context cont = new Context(tc.getModule(), InitScope.STATIC);
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

                        gprintln("Muh function handle: "~namedEntity.toString(), DebugType.WARNING);
                    }
                    else
                    {
                        /* TODO: Add check ? */
                    }
                    

                    
                }
                else
                {
                    expect("No entity by the name "~nearestName~" exists (at all)");
                }

               
            }
            /**
            * If the `path` has dots
            *
            * Example: `container.variableX`
            *
            * We want to start left to right, first look at `variableX`,
            * take that node, then recurse on `container.` (everything
            * without the last segment) as this results in the correct
            * dependency sub-tree
            *
            * FIXME: We should stop at `x.y` and not go further as we need
            * to know what we are acessing
            */
            else
            {
                /* Chop off the last segment */
                long lastDot = lastIndexOf(path, ".");
                string remainingSegment = path[0..(lastDot)];

                /* TODO: Check th container passed in */
                /* Lookup the name within the current entity's context */
                gprintln("Now looking up: "~remainingSegment);
                Entity namedEntity = tc.getResolver().resolveBest(context.getContainer(), remainingSegment);
                gprintln("namedEntity: "~to!(string)(namedEntity));
                gprintln("Context used for resolution: "~to!(string)(context.getContainer()));

                /* The remaining segment must EXIST */
                if(namedEntity)
                {
                    /* The remaining segment must be a CONTAINER */
                    Container container = cast(Container)namedEntity;
                    if(container)
                    {
                        /* If we have a class then it needs static init */
                        if(cast(Clazz)container)
                        {
                            Clazz containerClass = cast(Clazz)container;
                            DNode classStaticAllocate = classPassStatic(containerClass);
                            dnode.needs(classStaticAllocate);
                            gprintln("Hello "~remainingSegment, DebugType.ERROR);
                        }

                        /**
                        * FIXME: Decide what requires new dep and what doesn't, instance vs class access etc
                        *
                        * How detailed we need to be? Will we combine these and consume later, we need to take these things
                        * into account. I am erring on the side of one single access, the only things along the way are possible static
                        * allocations, but that is my feeling - each path segment doesn't need something for simply existing
                        */

                        /* If we only have one dot left s(TODO: implement ) */
                        bool hasMoreDot = indexOf(remainingSegment, ".") > -1;
                        if(hasMoreDot)
                        {
                            gprintln("has mor dot");

                            /**
                            * Create a VariableExpression for the remaining segment,
                            * run `passExpression()` on it (recurse) and make the CURRENT
                            * DNode (`dnode`) depend on the returned DNode
                            *
                            * TOOD: Double check the Context passed in
                            */
                            // Context varExpRemContext = new Context(tc.getModule(), InitScope.STATIC);
                            VariableExpression varExpRem = new VariableExpression(remainingSegment);
                            DNode varExpRemDNode = expressionPass(varExpRem, context);

                            /* TODO: Double check if we need this, problems lie here and when we NEED to do and and when NOT */
                            dnode.needs(varExpRemDNode);
                        }
                        else
                        {
                            /* Do access operation here */
                            gprintln("No more dot");

                            gprintln("No mord to accevssor(): "~to!(string)(dnode));

                            /* TODO: We now have `TestClass.P` so accessor op or what? */
                        }


                        


                        


                    }
                    else
                    {
                        expect("Could not acces \""~remainingSegment~"\" as it is not a container");
                    }

                }
                /**
                * If an entity by that name doesn't exist then
                * this is a typechecking error and we should
                * break
                */
                else
                {
                    expect("Could not find an entity named "~remainingSegment);
                }
            }

            /* TODO:C lean up and mke DNode */

            /* TODO: Process `nearestName` by doing a tc.resolveWithin() */


            

            /* TODO: SPlit the path up and resolve the shit */

            /* TODO: gte start of path  (TODO)*/
            /* TODO: Then check that within current context, then we shift context for another call */
            string currentName;

            /**
            * If we can resolve anywhere (TODO: Perhaps module level was better
            */
            if(context.isAllowUp())
            {
                /* TODO: Use normal resolveBest */
            }
            /**
            * Only within resolution allowed
            */
            else
            {
                gprintln("87er78fgy678fyg678g6f8gfyduhgfjfgdjkgfdhjkfgdhjfkgdhgfdjkhgfjkhgfdjkhgfdjkhgfdjkfgdhjkfgdhjkfdghjgkfdhgfdjkhgfdjkhgfdjkhfgdjkhfgd");
                Entity entity = tc.getResolver().resolveWithin(context.getContainer(), nearestName);

                /* TODO: If dots remain then make sure cast(Container)entity is non-zero, i.e. is a container, else fail, typecheck error! */
            }


            gprintln("VarExp Context set? (after): "~to!(string)(varExp.getContext()));

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
            gprintln("Working on expressionPass'ing of ArrayIndex", DebugType.ERROR);

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


            // assert(false);
        }
        else
        {
            // dnode = new DNode(this, exp);



            // dnode.needs()
            gprintln("Interesting", DebugType.ERROR);
        }
        



        return dnode;
    }


    import tlang.compiler.typecheck.dependency.variables;
    private ModuleVariableDeclaration pool_module_vardec(Variable entity)
    {
        foreach(DNode dnode; nodePool)
        {
            if(dnode.getEntity() == entity)
            {
                return cast(ModuleVariableDeclaration)dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        ModuleVariableDeclaration newDNode = new ModuleVariableDeclaration(this, entity);
        nodePool ~= newDNode;

        return newDNode;
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
                Struct structType = cast(Struct)variableType;

                import tlang.compiler.typecheck.dependency.declarables : StructTypeDeclarable;
                StructTypeDeclarable stdDNode = declareStructType(structType);
                variableDNode.needs(stdDNode);

                // Make a cloned-and-reparented copy
                Struct structInstance = cast(Struct)structType.clone(structType.parentOf());

                // We need a fresh clone of this struct type
                // such that we can treat all vardecs as unique
                // and not pool the same ones which would
                // affect their visitation status on first run

                // FIXME: THE POOL SHOULD BE OF A CLONE!
                // TODO: We may need to check this for 
                DNode structInstanceDNode = generalPass(structInstance, context);
                structInstanceDNode.name = "StructClone (of: "~structInstance.getName()~")"; // NOTE: Set this as it;s confusing otherwise

                // import tlang.compiler.typecheck.dependency.structInit : StructInstanceInit;
                // StructInstanceInit structInstantiateDNode = new StructInstanceInit(this, structInstance);

                // structInstantiateDNode.needs(structInstanceDNode);

                variableDNode.needs(structInstanceDNode);
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
                    gprintln("Advanced component types l;ike arrays of arrays or arrays of classes etc not yet supported", DebugType.ERROR);
                    assert(false);
                }

                gprintln("Arrays (and these are stack arrays) are not yet supported", DebugType.ERROR);
                // assert(false);
            }
            /* Anything else */
            else
            {
                /* This should never happen */
                gprintln(variableType);
                gprintln(variableType.classinfo);
                gprintln("#ThisShouldNeverHappen Fault: A variable declaration with a kind-of type we don't know", DebugType.ERROR);
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
            gprintln("YEAST ENJOYER");


            // FIXME: The below assert fails for function definitions trying to refer to global values
            // as a reoslveBest (up) is needed. We should firstly check if within fails, if so,
            // resolveBest, if that fails, then it is an error (see #46)
            assert(tc.getResolver().resolveBest(c, vAsStdAl.getVariableName()));
            gprintln("YEAST ENJOYER");
            Variable variable = cast(Variable)tc.getResolver().resolveBest(c, vAsStdAl.getVariableName());
            assert(variable);


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
            



            gprintln("Please implement array assignment dependency generation", DebugType.ERROR);
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
            gprintln("Hello");
            addFunctionDef(tc, func);

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

                gprintln("branch parentOf(): "~to!(string)(branch.parentOf()));
                assert(branch.parentOf());
                gprintln("branch generalPass(context="~to!(string)(context.getContainer())~")");

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
            gprintln("Branch: "~to!(string)(whileBranch));

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

            gprintln("Implement discard statement!", DebugType.ERROR);
            
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
            gprintln("Function calls (at statement level)", DebugType.INFO);

            // The FunctionCall is an expression, so to get a DNode from it `expressionPass()` it
            DNode funcCallDNode = expressionPass(funcCall, context);

            return funcCallDNode;
        }
        /** 
         * Struct declaration
         *
         * We ignore as not static initialization
         * is possible.
         */
        else if(cast(Struct)entity)
        {
            gprintln("Struct definition dependency", DebugType.ERROR);

            // NOTE: This is to be discarded as we are doing here
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
            root=pool(tc.getModule());
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
            gprintln("generalPass(): Processing entity: "~entity.toString());

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
                gprintln("Not adding dependency '"~to!(string)(statementDNode)~"' as it is null");
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
        

        foreach(DNode dnode; nodePool)
        {
            Statement entity = dnode.getEntity();
            if(entity == clazz && cast(ClassStaticNode)dnode)
            {
                return cast(ClassStaticNode)dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        ClassStaticNode newDNode = new ClassStaticNode(this, clazz);
        nodePool ~= newDNode;

        return newDNode;
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

        gprintln("classPassStatic(): Static init check for?: "~to!(string)(clazz));

        /* Make sure we are static */
        if(clazz.getModifierType()!=InitScope.STATIC)
        {
            gprintln("classPassStatic(): Not static class", DebugType.ERROR);
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

    import tlang.compiler.typecheck.dependency.declarables : StructTypeDeclarable;
    import tlang.compiler.symbols.containers : Struct;
    private StructTypeDeclarable declareStructType(Struct typeToDeclare)
    {
        // Pool
        StructTypeDeclarable dnode = poolT!(StructTypeDeclarable, Struct)(typeToDeclare);

        // If we have visited return us
        if(dnode.isVisisted())
        {
            return dnode;
        }
        else
        {
            /* Set as visited */
            dnode.markVisited();
        }
        
        generalPass(typeToDeclare, new Context(typeToDeclare, InitScope.STATIC));

        return dnode;
    }

}