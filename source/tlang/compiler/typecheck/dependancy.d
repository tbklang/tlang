module compiler.typecheck.dependancy;

import gogga;
import compiler.symbols.data;
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
    */
}