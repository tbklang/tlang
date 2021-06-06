module compiler.typecheck.dependancy;

import gogga;
import compiler.symbols.data;
import compiler.symbols.typing.core;
import compiler.typecheck.core;

import std.conv : to;

public final class StructuralOrganizer
{
    /* The associated TypeChecker */
    private TypeChecker tc;

    this(TypeChecker tc)
    {
        this.tc = tc;
    }

    /* TODO: Return a list of Statement, in their init order */
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
                }


                /* TODO: Handle assignment case */
                if(variable.getAssignment())
                {
                    /* TODO: Implement me */
                }
            }
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