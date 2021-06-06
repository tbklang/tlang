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
        * Encounter yourself as to not be lost if you need not depens on anything else
        * cause if this is not done then we can easily forget `int jNumber;` at module-level
        * for example.
        */
        encounter(tc, entity, entity);

        /**
        * If we are at Module level then things differ
        * ever so slightly
        */
        if(container == tc.getModule())
        {
            /**
            * If we have a module-level variable declaration then we want to check
            * if the type of the variable being declared is:
            *
            * 1. Basic (int, float, etc.)
            *   - Then we will do nothing, it is not dependent
            * 2. Non-basic (Class-case only)
            *   - Then we will check if that class is accessible
            *       1. If it is at the module-level then it is implied static so it would be
            *       2. If at a level deeper then more care must be taken
            *
            * TODO: Assignments still not supported as this means more checking
            */
            if(cast(Variable)entity)
            {
                Variable variable = cast(Variable)entity;

                /* Get the variable's type */
                Type variableType = tc.getType(container, variable.getType());

                /**
                * Check if the type is a class type
                */
                if(cast(Clazz)variableType)
                {
                    Clazz classType = cast(Clazz)variableType;

                    /* If the class is defined at the module-level then it is static by default */
                    if(classType.parentOf() == tc.getModule())
                    {
                        /**
                        * Then mark the class as a dependency (the class-name/type reference)
                        * must cause the static initialization to go off
                        *
                        * module pp;
                        *   Person k;
                        *   class Person { }
                        *
                        * Above it means that because the type of `k` is `Person` and that is a
                        * class type therefore the Person class should have its static constructor
                        * run (=> all static members should be initialized)
                        */
                        encounter(tc, variable, classType);
                    }
                    else
                    {
                        /* TODO: Possible errors but may work too */
                        gprintln("Woah there cowboy, this is dangerous territory", DebugType.WARNING);
                    }
                }
                /**
                * Anything else (TODO: Checking)
                */
                else
                {
                    /* TODO: EVerything else is fine */
                    /* TODO: Either struct or primtive, neither have static initlization */
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
            gprintln("BAAD", DebugType.ERROR);
            assert(false);
        }
    }
}