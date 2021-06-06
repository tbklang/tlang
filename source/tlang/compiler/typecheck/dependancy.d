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

/**
* Given a path to a class and a relative container to start at
* this will start at the top of the path and dependencyGneerate
* on each of them
*
* Example:
*
* module j;
* A.B.C cInstance;
*
* class A
* {
*    class B
*    {
*
*    }
* }
*/

/* TODO: Implement me */


public bool hasDepChecked(TypeChecker tc, Entity entity)
{
    /* Full path of the entity */
    string entityFullPath = tc.getResolver().generateName(tc.getModule(), entity);

    /**
    * Check if it is in there
    */
    foreach(string key; deps.keys)
    {
        import std.string : cmp;
        if(cmp(key, entityFullPath) == 0)
        {
            return true;
        }
    }
    
    return false;
}


/**
* Statically initilizes a given class
*/
public void staticInitClass(TypeChecker tc, Clazz clazz)
{
    /**
    * Don't init if we have initted before
    */
    if(hasDepChecked(tc, clazz))
    {
        return;
    }



    /**
    * Get all Entities of the class that are static
    */
    Entity[] staticEntities;
    foreach (Statement statement; clazz.getStatements())
    {
        if (statement !is null && cast(Entity) statement)
        {
            Entity entity = cast(Entity)statement;
            if(entity.getModifierType() == InitScope.STATIC)
            {
                staticEntities ~= cast(Entity) statement;    
            }
        }
    }

    /**
    * Process the static members
    */
    foreach(Entity staticMember; staticEntities)
    {
        /**
        * If the static member is a variable
        * declaration
        */
        if(cast(Variable)staticMember)
        {
            Variable variable = cast(Variable)staticMember;

            /* Get the variable's type */
            Type variableType = tc.getType(clazz, variable.getType());

            /**
            * Check if the type is a class type
            */
            if(cast(Clazz)variableType)
            {
                Clazz classType = cast(Clazz)variableType;

                /* Static initialize the class */
                staticInitClass(tc, classType);
            }


            /* This class depends on this variable being initialized */
            encounter(tc, clazz, variable);
            
            /* If then variable has an assignment */
            if(variable.getAssignment())
            {
                /* TODO: Add assignment support */    
            }
        }
        
    }
}

public void virtualInitClass(TypeChecker tc, Clazz clazz)
{

}



/**
* Returns true if the path downwards is all static dentities
*/

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
    *
    * If, for example, we have `A aInstance;` as a module-level variable declaration then
    * we must statically initialize A (the class as that is a class-type reference) - we do
    * this by visiting the class and initializing all of it's things
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
                        *
                        * Okay, so we do all of the above SECOND, first the class must be checked itself
                        */
                        staticInitClass(tc, classType);
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

                    /* We need to still know it exists */
                    encounter(tc, variable, variable);
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
            /* TODO: Only should be called in static-initialization case */
            // Clazz clazz = cast(Clazz)container;
            // assert(clazz.);



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