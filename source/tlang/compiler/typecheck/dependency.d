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
    private Statement entity;


    private DNodeGenerator dnodegen;
    private Resolver resolver;

    private bool visited;
    private bool complete;
    private DNode[] dependencies;

    this(DNodeGenerator dnodegen, Statement entity)
    {
        this.entity = entity;
        this.dnodegen = dnodegen;
        this.resolver = dnodegen.resolver;
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

    public string print()
    {
        string spaces = "            ";
        /* The tree */ /*TODO: Make genral to statement */
        string tree = "   ";
        tree ~= resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);

        ulong c = count(resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity));

        tree ~= "\n";
        foreach(DNode dependancy; dependencies)
        {
            if(!dependancy.isCompleted())
            {
                dependancy.markCompleted();
                tree ~= spaces[0..(c+1)*3]~dependancy.print();
            }
            
        }

        markCompleted();

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
        root = moduleDNode;

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

    private DNode modulePass(Module modulle)
    {
        /* Get a DNode for the Module */
        DNode moduleDNode = pool(modulle);

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
                DNode variableDNode = pool(variable);

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

                /* If there is an assignment attached to this */
                if(variable.getAssignment())
                {
                    /* (TODO) Process the assignment */
                }

                /* Set as visited */
                variableDNode.markVisited();
            }
        }

        return moduleDNode;
    }

    import compiler.typecheck.classStaticDep;
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
                    DNode variableDNode = pool(variable);

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