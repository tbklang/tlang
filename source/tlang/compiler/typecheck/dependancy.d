module compiler.typecheck.dependancy;

import gogga;
import compiler.symbols.data;
import compiler.symbols.typing.core;
import compiler.typecheck.core;

import std.conv : to;

/**
* A list of all the full-paths of entities and what they rely on
*
* TODO:
* So far we are looking at types and seeing what they depend on, not yet
* for assignments. When we get to assignments we should then add more
*/
public string[][string] deps;


public void encounter(string entityName, string dependentOn)
{
    deps[entityName] ~= dependentOn;
    gprintln("[Encounter] Entity: \""~entityName~"\" set to be dependent on \""~dependentOn~"\"");
}

public void encounter(TypeChecker tc, Entity entityDependee, Entity dependentOn)
{
    /* Full path of thing depending on something else */
    string dependee = tc.getResolver().generateName(tc.getModule(), entityDependee);

    /* Full path of the thing it is dependent on */
    string dependency = tc.getResolver().generateName(tc.getModule(), dependentOn);

    encounter(dependee, dependency);
}

public void dependancyGenerate(TypeChecker tc, Container container)
{
    /**
    * The Container Entity
    */
    Entity containerEntity = cast(Entity)container;
    assert(containerEntity);
    string containerEntityName = tc.getResolver().generateName(tc.getModule(), containerEntity);

    /**
    * Get all Entities
    */
    Entity[] containerEntities;
    foreach (Statement statement; container.getStatements())
    {
        if (statement !is null && cast(Entity) statement)
        {
            containerEntities ~= cast(Entity) statement;    
        }
    }

    gprintln("[dependencyGenerate] Container: \""~containerEntityName~"\" has the following members:\n\n"~to!(string)(containerEntities));

    /**
    * Process all entities
    *
    * The natural order would be classes, funcitons/variables (I cannot remember TOOD: check this)
    */
    foreach(Entity entity; containerEntities)
    {
        /**
        * If we are at Module level then things differ
        * ever so slightly
        */
        if(container == tc.getModule())
        {
            /**
            * If it is a variable
            */
            if(cast(Variable)entity)
            {
                Variable variable = cast(Variable)entity;

                /* Get the variable's type */
                Type variableType = tc.getType(container, variable.getType());

                /**
                * TODO: Here we must decide, if it is basic type then no init -> no dependence
                * The only depenedence would be what comes next (a.k.a. if an assignment exists)
                * then dependence from the expression must be checked
                *
                * Non-basic types that have static initiliazation on type reference: Class
                */
                if(cast(Clazz)variableType)
                {
                    /**
                    * Mark the variable as dependent on the class type (`variableType`) having 
                    * been statically initialized
                    */
                    encounter(tc, variable, variableType);
                }

                /* If then variable has an assignment */
                if(variable.getAssignment())
                {
                    /* TODO: Add assignment support */    
                }
            }
        }
        /**
        * If we are at the Class level
        */
        else if(cast(Clazz)container)
        {

        }
        /**
        * If we are at the Struct level
        */
        else if(cast(Struct)container)
        {

        }
        /**
        * Any other type of Container
        */
        else
        {
            /* This shouldn't happen */
            assert(false);
        }
    }
}