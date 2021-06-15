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

        if(cast(Entity)entity || cast(VariableAssignment)entity)
        {
            tree ~= name;
        }
        else
        {
            tree ~= entity.toString();
        }

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
    */
    private final class Context
    {
        InitScope initScope;
        Container container;

        this(Container container, InitScope initScope)
        {
            this.initScope = initScope;
            this.container = container;
        }
    }
    
    import compiler.typecheck.expression;

    private DNode expressionPass(Expression exp, Context context)
    {
        DNode dnode;

        gprintln("expressionPass(Exp): Processing "~exp.toString(), DebugType.WARNING);

        /* TODO: Add pooling */

        /**
        * Number literal
        */
        if(cast(NumberLiteral)exp)
        {
            return new DNode(this, exp);
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
            dnode = poolT!(ExpressionDNode, NewExpression)(newExpression);

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
            return new DNode(this, exp);


        }
        /**
        * Binary operator
        */
        else if(cast(BinaryOperatorExpression)exp)
        {
            /* Get the binary operator expression */
            BinaryOperatorExpression binOp = cast(BinaryOperatorExpression)exp;
            dnode = new DNode(this, exp);

            /* Process left and right */
            DNode leftNode = expressionPass(binOp.getLeftExpression(), context);
            DNode rightNode = expressionPass(binOp.getRightExpression(), context);

            /* Require the evaluation of these */
            /* TODO: Add specific DNode type dependent on the type of operator */
            dnode.needs(leftNode);
            dnode.needs(rightNode);
        }
        else
        {
            dnode = new DNode(this, exp);



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