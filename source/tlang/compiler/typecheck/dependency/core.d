module compiler.typecheck.dependency.core;

import compiler.symbols.check;
import compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import compiler.parsing.core;
import compiler.typecheck.resolution;
import compiler.typecheck.exceptions;
import compiler.typecheck.core;
import compiler.symbols.typing.core;
import compiler.symbols.typing.builtins;



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



    public static DNode[] poes;

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

    public string print()
    {
        string spaces = "                                                ";
        /* The tree */ /*TODO: Make genral to statement */
        string tree = "   ";

        // if(cast(Entity)entity || cast(VariableAssignment)entity)
        // {
        //     tree ~= name;
        // }
        // else
        // {
        //     tree ~= entity.toString();
        // }

        tree ~= name;

        tree ~= "\n";
        c++;
        foreach(DNode dependancy; dependencies)
        {
            if(!dependancy.isCompleted())
            {
                dependancy.markCompleted();

               

                tree ~= spaces[0..(c)*3]~dependancy.print();
            }
            
        }

        markCompleted();

         /* TODO: I think using `isDone` we can linearise */
        gprintln("Done/Not-done?: "~to!(string)(isDone));

        if(isDone)
        {
            poes ~= this;
        }

        c--;
        return tree;
    }

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
    private DNode[] nodePool;

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


    
    
    import compiler.typecheck.dependency.expression;
    import compiler.typecheck.dependency.classes.classObject;
    import compiler.typecheck.dependency.classes.classVirtualInit;

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
            Entity funcEntity = resolver.resolveWithin(context.container, funcCall.getName());
            DNode funcDefDNode = retrieveFunctionDefinitionNode(tc.getResolver().generateName(tc.getModule(), funcEntity));
            gprintln("FuncCall (FuncDefNode): "~to!(string)(funcDefDNode));
            dnode.needs(funcDefDNode); /* NOTE: New code as of 4th October 2022 */


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
                    Parser.expect("Only class-type may be used with `new`");
                    assert(false);
                }
                gprintln("Poe naais");
            }
            else
            {
                Parser.expect("Invalid ryp");
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

            /* NOTE: Fix is below I think (it doesn't crash then) */
            /* Set context for expression and the variable itself */
            // varExp.setContext(context);
            // Entity bruh = tc.getResolver().resolveBest(context.getContainer(), path);
            // bruh.setContext(context);
          



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
                Entity namedEntity = tc.getResolver().resolveWithin(context.getContainer(), nearestName);



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
                            Parser.expect("Cannot reference variable "~nearestName~" which exists but has not been declared yet");
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
                    Parser.expect("No entity by the name "~nearestName~" exists (at all)");
                }

               
            }
            /**
            * If the `path` has dots
            *
            * Example: `container.variableX`
            */
            else
            {
                /* Get name before the first dot */
                nearestName = path[0..nearestDot];

                /* Resolve the Entity */
                Entity namedEntity = tc.getResolver().resolveWithin(context.getContainer(), nearestName);

                /**
                * If an entity by that name exists
                */
                if(namedEntity)
                {
                    /* TODO: Reusrse */



                    /* TODO: Create a DNode for a variable access */
                }
                /**
                * If an entity by that name doesn't exist then
                * this is a typechecking error and we should
                * break
                */
                else
                {
                    Parser.expect("Could not find an entity named "~nearestName);
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
        else
        {
            // dnode = new DNode(this, exp);



            // dnode.needs()
        }
        



        return dnode;
    }


    import compiler.typecheck.dependency.variables;
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
            if(ent && ent.getModifierType() != InitScope.STATIC && ignoreInitScope)
            {
                writeln("Did we just skip someone?");
                writeln(ent);
                continue;
            }

            /**
            * Variable declarations
            */
            if(cast(Variable)entity)
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

                /* Basic type */
                if(cast(Primitive)variableType)
                {
                    /* Do nothing */
                }
                /* Class-type */
                else if(cast(Clazz)variableType)
                {
                    /* Get the static class dependency */
                    ClassStaticNode classDependency = classPassStatic(cast(Clazz)variableType);

                    /* Make this variable declaration depend on static initalization of the class */
                    variableDNode.needs(classDependency);
                }
                /* Struct-type */
                else if(cast(Struct)variableType)
                {

                }
                /* Anything else */
                else
                {
                    /* This should never happen */
                    assert(false);
                }


                /* Set this variable as a dependency of this module */
                node.needs(variableDNode);

                /* Set as visited */
                variableDNode.markVisited();

                /* If there is an assignment attached to this */
                if(variable.getAssignment())
                {
                    /* (TODO) Process the assignment */
                    VariableAssignment varAssign = variable.getAssignment();

                    DNode expression = expressionPass(varAssign.getExpression(), context);

                    VariableAssignmentNode varAssignNode = new VariableAssignmentNode(this, varAssign);
                    varAssignNode.needs(expression);

                    variableDNode.needs(varAssignNode);
                }

                
            }
            /**
            * Variable asignments
            */
            else if(cast(VariableAssignmentStdAlone)entity)
            {
                VariableAssignmentStdAlone vAsStdAl = cast(VariableAssignmentStdAlone)entity;

                /* TODO: CHeck avriable name even */
                gprintln("VAGINA");
                assert(tc.getResolver().resolveWithin(c, vAsStdAl.getVariableName()));
                gprintln("VAGINA");
                Variable variable = cast(Variable)tc.getResolver().resolveWithin(c, vAsStdAl.getVariableName());
                assert(variable);
                /* Pool the variable */
                DNode varDecDNode = pool(variable);

                /* TODO: Make sure a DNode exists (implying it's been declared already) */
                if(varDecDNode.isVisisted())
                        {
                            /* Pool varass stdalone */
                            DNode vStdAlDNode = pool(vAsStdAl);
                            node.needs(vStdAlDNode);

                         DNode expression = expressionPass(vAsStdAl.getExpression(), context);
                         vStdAlDNode.needs(expression);
                            
                        }
                        else
                        {
                            Parser.expect("Cannot reference variable "~vAsStdAl.getVariableName()~" which exists but has not been declared yet");
                        }
            }
            /**
            * Function declarations
            * Status: Not done (TODO)
            */
            else if(cast(Function)entity)
            {
                // /* Grab the function */
                Function func = cast(Function)entity;

                // /* Set the context to be STATIC and relative to this Module */
                // Context d = new Context( cast(Container)modulle, InitScope.STATIC);
                // func.setContext(d);

                // /* Pass the function declaration */
                // DNode funcDep = FunctionPass(func);

                // /* TODO: Surely we only require the module, it doesn't need us? */
                // /* TODO: Perhaps, no, it needs us to make it into the tree */
                // /* TODO: But NOT it's subcompnents */
                // funcDep.needs(moduleDNode);
                // moduleDNode.needs(funcDep); /* TODO: Nah fam looks weird */

                /**
                * TODO:
                *
                * Perhaps all function calls should look up this node
                * via pooling it and then they should depend on it
                * which depends on module init
                *
                * Then whatever depends on function call will have module dependent
                * on it, which does this but morr round about but seems to make more
                * sense, idk
                */

                /**
                * SOLUTION
                *
                * DOn;'t process declarations
                * Process function calls, then look up the Function (declaration)
                * and go through it pooling and seeing it's needs
                */

                /**
                * Other SOLUTION
                * 
                * We go through and process the declaration and get
                * what each variable depends on, we then return this
                * And we have a function that does that for us
                * but WE DON'T IMPLEMENT THAT HERE IN modulePass()
                *
                * Rather each call will do it, and because we pool
                * we will add DNOdes that then flatten out
                */

                /**
                * EVEN BETTER (+PREVIOUS SOLUTION)
                *
                * We process it here yet we do not
                * add thre entity themselves as dnodes
                * only their dependents and return that
                * Accounting ONLY for external dependencies
                * WE STORE THIS INA  FUNCTIONMAP
                *
                * We DO call this here
                *
                * On a FUNCTION **CALL** do a normal pass on
                * the FUNCTIONMAP entity, in a way that doesn't
                * add to our tree for Modulle. Effectively
                * giving us a uniue dependecny tree per call
                * which is fine for checking things and also
                * for (what is to come - code generation) AS
                * THEN we want duplication. Calling something
                * twice means two sets of instructions, not one
                * (as a result from pooled dependencies or USING
                * the same pool)
                */

                /* Add funtion definition */
                gprintln("Hello");
                addFunctionDef(tc, func);

                /* TODO: Hoist stuff from pre-processing */

                /* TODO: New code from 1st October */
                /* Recurse downwards */
                /* FIXME: The context container must be fixed, see passClazz, we pass the euiavlent of `func` in there */
                Context funcContext = new Context(tc.getModule(), InitScope.STATIC);
                DNode funcDefDNode = generalPass(func, funcContext);


                /**
                * Save the function dnode for lookup later
                */
                saveFunctionDefinitionNode(funcDefDNode);
            }

        }

        return node;
    }

    import compiler.typecheck.dependency.classes.classStaticDep;
    private ClassStaticNode poolClassStatic(Clazz clazz)
    {
        /* Sanity check */
        if(clazz.getModifierType() != InitScope.STATIC)
        {
            Parser.expect("SanityCheck: poolClassStatic(): Cannot pool a non-static class");
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

}