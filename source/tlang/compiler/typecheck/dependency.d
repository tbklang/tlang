module compiler.typecheck.dependency;

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
        c--;
        return tree;
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
    * DNode pool
    *
    * This holds unique pool entries
    */
    private DNode[] nodePool;

    this(TypeChecker tc)
    {
        this.tc = tc;
        this.resolver = tc.getResolver();

        /* TODO: Make this call in the TypeChecker instance */
        generate();
    }

    public DNode root;


    private void generate()
    {
        /* Start at the top-level container, the module */
        Module modulle = tc.getModule();

        /* Recurse downwards */
        DNode moduleDNode = modulePass(modulle);

        /* Print tree */
        gprintln("\n"~moduleDNode.print());
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


    /**
    * Passed around
    *
    * 1. Contains containership (some Statements are not contained) so we need to track this
    * 2. InitScope, STATIC or VIRTUAL permission
    * 3. `allowUp`, when resolving names in this Context use
    * resolveBest instead of resolveWithin (stay inside Context solely
    * don't travel up parents)
    */
    private final class Context
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
    }
    
    import compiler.typecheck.expression;
    import compiler.typecheck.classes.classObject;
    import compiler.typecheck.classes.classVirtualInit;

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
        */
        else if(cast(VariableExpression)exp)
        {
            /* TODO: Figure out where the variable lies */

            /* TODO: Change this later */
            // return new DNode(this, exp);

            /**
            * Extract the variable name
            * I actually forgot how this worked lmao
            */
            VariableExpression varExp = cast(VariableExpression)exp;
            string path = varExp.getName();

            /**
            * If we can resolve anywhere 
            */
            if(context.isAllowUp())
            {
                /* TODO: Use normal resolveBest */
            }
            /**
            * Only donwards resolution allowed
            */
            else
            {
                gprintln("87er78fgy678fyg678g6f8gfyduhgfjfgdjkgfdhjkfgdhjfkgdhgfdjkhgfjkhgfdjkhgfdjkhgfdjkfgdhjkfgdhjkfdghjgkfdhgfdjkhgfdjkhgfdjkhfgdjkhfgd");

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
        else
        {
            // dnode = new DNode(this, exp);



            // dnode.needs()
        }
        



        return dnode;
    }


    import compiler.typecheck.variables;
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




    private DNode modulePass(Module modulle)
    {
        /* Get a DNode for the Module */
        DNode moduleDNode = pool(modulle);
        root = moduleDNode;

        /**
        * Get the Entities
        */
        Entity[] entities;
        foreach(Statement statement; modulle.getStatements())
        {
            if(!(statement is null) && cast(Entity)statement)
            {
                entities ~= cast(Entity)statement;
            }
        }

        /**
        * Process each Entity
        *
        * TODO: Non entities later
        */
        foreach(Entity entity; entities)
        {
            /**
            * Variable declarations
            */
            if(cast(Variable)entity)
            {
                /* Get the Variable and information */
                Variable variable = cast(Variable)entity;
                Type variableType = tc.getType(modulle, variable.getType());
                assert(variableType); /* TODO: Handle invalid variable type */
                DNode variableDNode = poolT!(ModuleVariableDeclaration, Variable)(variable);

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
                moduleDNode.needs(variableDNode);

                /* Set as visited */
                variableDNode.markVisited();

                /* If there is an assignment attached to this */
                if(variable.getAssignment())
                {
                    /* (TODO) Process the assignment */
                    VariableAssignment varAssign = variable.getAssignment();

                    DNode expression = expressionPass(varAssign.getExpression(), new Context(modulle, InitScope.STATIC));

                    VariableAssignmentNode varAssignNode = new VariableAssignmentNode(this, varAssign);
                    varAssignNode.needs(expression);

                    variableDNode.needs(varAssignNode);
                }

                
            }
        }

        return moduleDNode;
    }

    import compiler.typecheck.classes.classStaticDep;
    private ClassStaticNode poolClassStatic(Clazz clazz)
    {
        /* Sanity check */
        assert(clazz.getModifierType() == InitScope.STATIC);

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
        
        gprintln("poes");

        /**
        * Get the Entities
        */
        Entity[] entities;
        foreach(Statement statement; clazz.getStatements())
        {
            if(!(statement is null) && cast(Entity)statement)
            {
                entities ~= cast(Entity)statement;
            }
        }

        /**
        * Process all static members
        *
        * TODO: Non-Entities later
        */
        foreach(Entity entity; entities)
        {
            if(entity.getModifierType() == InitScope.STATIC)
            {
                /**
                * Variable declarations
                */
                if(cast(Variable)entity)
                {
                    /* Get the Variable and information */
                    Variable variable = cast(Variable)entity;
                    Type variableType = tc.getType(clazz, variable.getType());
                    gprintln(variable.getType());
                    assert(variableType); /* TODO: Handle invalid variable type */
                    DNode variableDNode = poolT!(StaticVariableDeclaration, Variable)(variable);

                    /* Basic type */
                    if(cast(Primitive)variableType)
                    {
                        /* Do nothing */
                    }
                    /* Class-type */
                    else if(cast(Clazz)variableType)
                    {
                        /* If the class type is THIS class */
                        if(variableType == clazz)
                        {
                            /* Do nothing */
                        }
                        /* If it is another type */
                        else
                        {
                            /* Get the static class dependency */
                            ClassStaticNode classDependency = classPassStatic(cast(Clazz)variableType);

                            /* Make this variable declaration depend on static initalization of the class */
                            variableDNode.needs(classDependency);
                        }
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
                    classDNode.needs(variableDNode);

                    /* If there is an assignment attached to this */
                    if(variable.getAssignment())
                    {
                        /* (TODO) Process the assignment */
                    }

                    /* Set as visited */
                    variableDNode.markVisited();
                }
            }
        }

        return classDNode;
    }

}