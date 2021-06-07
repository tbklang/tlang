module compiler.typecheck.dependancy;

import gogga;
import compiler.symbols.data;
import compiler.symbols.typing.core;
import compiler.typecheck.core;
import std.conv : to;
import compiler.parsing.core;

public final class StructuralOrganizer
{
    /* The associated TypeChecker */
    private TypeChecker tc;

    private TreeNode root;

    this(TypeChecker tc)
    {
        this.tc = tc;
    }


    public void generate()
    {
        root = poolNode(tc.getModule());
        checkContainer(tc.getModule());
    }

    /**
    * Given a container this method will attempt to build
    * an implicit dependency tree (by setting the dependencies)
    * on the Entities contained within
    */
    public void checkContainer(Container container)
    {
        /* Get all Entities */
        Entity[] entities;
        foreach(Statement statement; container.getStatements())
        {
            if(statement !is null && cast(Entity)statement)
            {
                entities ~= cast(Entity)statement;
            }
        }

        /**
        * Process entities
        */
        foreach(Entity entity; entities)
        {
            /**
            * Variable declaration
            */
            if(cast(Variable)entity)
            {
                /* Variable being declared */
                Variable variable = cast(Variable)entity;

                /* Get the variable's type */
                Type type = tc.getType(container, variable.getType());

                /* If the variable has a class-type */
                if(cast(Clazz)type)
                {
                    /* Get the class-type */
                    Clazz classType = cast(Clazz)type;

                    /* TODO: Ensure that we set dependences as A.B.C with A B C all static */
            
                    /* Statically initialize the class (make module depend on it) */
                    TreeNode classWalkInitDep = staticInitializeClass(classType);
                    root.addDep(classWalkInitDep);

                    /* Make the Module depend on this variable being initialized */
                    TreeNode varNode = poolNode(variable);
                    root.addDep(varNode);
                }


                /* TODO: Handle assignment case */
                if(variable.getAssignment())
                {
                    /* TODO: Implement me */
                    VariableAssignment varAssign = variable.getAssignment();
                    gprintln("Assignment: "~to!(string)(varAssign));
                }
            }
        }
    }

    private TreeNode[] nodePool;

    public TreeNode poolNode(Entity entity)
    {
        foreach(TreeNode node; nodePool)
        {
            if(node.getEntity() == entity)
            {
                return node;
            }
        }

        TreeNode node = new TreeNode(tc, entity);
        nodePool ~= node;

        return node;
    }

    public bool isPooled(Entity entity)
    {
        foreach(TreeNode node; nodePool)
        {
            if(node.getEntity() == entity)
            {
                return true;
            }
        }

        return false;
    }

    /**
    * Statically initialize a class
    *
    * Outer class first then inner things
    *
    * TODO: Possible re-ordering would be needed
    */
    public TreeNode staticInitializeClass(Clazz clazz)
    {
        /**
        * This is a recursive static initiliazer, all classes
        * must be static
        */
        if(clazz.getModifierType() != InitScope.STATIC)
        {
            Parser.expect("Cannot use a class type that is of a class that is non-static");
        }

        /**
        * This Class's TreeNode
        */
        TreeNode treeNode;

        if(isPooled(clazz))
        {
            treeNode = poolNode(clazz);
            return treeNode;
            // goto static_initialization_completed;
        }
        else
        {
            treeNode = poolNode(clazz);
        }


        

        /**
        * Check if the current Clazz has a parent Container
        * that is a Clazz, then go statically initialize that
        * first
        */
        if(cast(Clazz)(clazz.parentOf()))
        {
            /* Statically initialize the parent class */
            TreeNode parentNode = staticInitializeClass(cast(Clazz)(clazz.parentOf()));

            /* Set the child class to depend on the parent's static initialization */
            treeNode.addDep(treeNode);
        }

        /* Get all Entities */
        Entity[] entities;
        foreach(Statement statement; clazz.getStatements())
        {
            if(statement !is null && cast(Entity)statement)
            {
                entities ~= cast(Entity)statement;
            }
        }

        /**
        * Process static entities
        *
        * Here we first want to mark the statics that have basic types
        * or non-basic class types that match our class
        */
        foreach(Entity entity; entities)
        {
            if(entity.getModifierType() == InitScope.STATIC)
            {
                /**
                * Static Variable declarations
                */
                if(cast(Variable)entity)
                {
                    /* Variable being declared */
                    Variable variable = cast(Variable)entity;
                    TreeNode variableTNode = poolNode(variable);

                    /* Get the variable's type */
                    Type type = tc.getType(clazz, variable.getType());

                    /* If the variable's type basic */
                    if(cast(Primitive)type)
                    {
                        /* TODO: Init */
                        /* Immediately set as init, no further static recursion */
                        treeNode.addDep(variableTNode);
                    }
                    /* If the variable's type is class-type */
                    else if(cast(Clazz)type)
                    {
                        /* If it is ours */
                        if(type == clazz)
                        {
                            /* Immediately set as init, no further static recursion */
                            treeNode.addDep(variableTNode);
                        }
                        /* Else init the class AND then the variable */
                        else
                        {
                            treeNode.addDep(staticInitializeClass(cast(Clazz)type));
                            treeNode.addDep(variableTNode);
                        }
                    }
                    else
                    {
                        /* TODO: dik */
                    }


                    /* TODO: Implement this later */
                    if(variable.getAssignment())
                    {

                    }
                }
                /* Static class definitions */
                else if(cast(Clazz)entity)
                {
                    /* Statically initialize the static class */
                    staticInitializeClass(cast(Clazz)entity);
                }
            }
        }

        static_initialization_completed:

        return treeNode;
    }

    /**
    * Given a `class A {}` this will make sure all static allocations
    *
    */
    private void staticInitializeClass_reorder(Clazz)
    {

    }



    public void printPool()
    {
        foreach(TreeNode node; nodePool)
        {
            gprintln(node, DebugType.WARNING);
        }
    }

    /**
    * Given a path determine if it is accessible (in a static context)
    *
    * TODO: Explain
    *
    * If so, return the order of static initializations
    */
    // public string[]
}

public class TreeNode
{
    private Entity entity;
    private TreeNode[] deps;
    private TypeChecker tc;

    this(TypeChecker tc, Entity entity)
    {
        this.entity = entity;
        this.tc = tc;
    }

    public void addDep(TreeNode node)
    {
        /* Only add if not already added */
        foreach(TreeNode cNode; deps)
        {
            if(cNode == node)
            {
                return;
            }
        }

        deps ~= node;
    }

    public TreeNode isDep(Entity entity)
    {
        foreach(TreeNode node; deps)
        {
            if(node.getEntity() == entity)
            {
                return node;
            }
        }

        return null;
    }

    public Entity getEntity()
    {
        return entity;
    }

    public override string toString()
    {
        string[] names;
        foreach(TreeNode node; deps)
        {
            names ~= tc.getResolver().generateName(tc.getModule(), node.getEntity());
        }

        return "TreeNode ("~entity.getName()~"): "~to!(string)(names);
    }

 
}