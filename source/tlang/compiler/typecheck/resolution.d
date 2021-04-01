module compiler.typecheck.resolution;

import compiler.typecheck.core;
import gogga;
import compiler.symbols.data;
import std.string;

public final class Resolver
{
    /* Associated TypeChecker engine */
    private TypeChecker typeChecker;

    this(TypeChecker typeChecker)
    {
        this.typeChecker = typeChecker;
    }

    /**
    * Given an Entity generate it's full path relative to a given
    * container
    */
    public string generateName(Container relativeTo, Entity entity)
    {
        string[] name = generateName_Internal(relativeTo, entity);
        string path;
        for(ulong i = 0; i < name.length; i++)
        {
            path ~= name[name.length-1-i];

            if(i != name.length-1)
            {
                path ~= ".";
            }
        }

        return path;
    }

    private string[] generateName_Internal(Container relativeTo, Entity entity)
    {
        /**
        * If the Entity and Container are the same then
        * just returns its name
        */
        if(relativeTo == entity)
        {
            return [relativeTo.getName()];
        }
        /**
        * If the Entity is contained within the Container
        */
        else if(isDescendant(relativeTo, entity))
        {
            string[] items;

            Entity currentEntity = entity;
            do
            {
                items ~= currentEntity.getName();
                currentEntity = currentEntity.parentOf();
            }
            while(currentEntity != relativeTo);

            /* Add the relative to container */
            items ~= relativeTo.getName();

            return items;
        }
        /* If not */
        else
        {
            return null;
        }
    }

    /**
    * Returns true if Entity e is C or is within
    * (contained under c), false otherwise
    */
    public bool isDescendant(Container c, Entity e)
    {
        /**
        * If they are the same
        */
        if(c == e)
        {
            return true;
        }
        /**
        * If not, check descendancy
        */
        else
        {
            Entity currentEntity = e;

            do
            {
                currentEntity = currentEntity.parentOf();

                if(currentEntity == c)
                {
                    return true;
                }
            }
            while(currentEntity);

            return false;
        }
    }

    public Entity resolveWithin(Container currentContainer, string name)
    {
        Statement[] statements = currentContainer.getStatements();

        foreach(Statement statement; statements)
        {
            /* TODO: Only acuse parser not done yet */
            if(statement !is null)
            {
                Entity entity = cast(Entity)statement;

                if(entity)
                {
                    if(cmp(entity.getName(), name) == 0)
                    {
                        return entity;
                    }
                }
            }   
        }

        return null;
    }   

    public Entity resolveUp(Container currentContainer, string name)
    {
        // /* If given container is null */
        // if(!currentContainer)
        // {
        //     return null;
        // }

        /* Try find the Entity within the current Contaier */
        Entity entity = resolveWithin(currentContainer, name);
        gprintln("Poes");
        gprintln(entity);

        /* If we found it return it */
        if(entity)
        {
            return entity;
        }
        /* If we didn't then try go up a container */
        else
        {
            Container possibleParent = currentContainer.parentOf();

            /* Can we go up */
            if(possibleParent)
            {
                return resolveUp(possibleParent, name);
            }
            /* If the current container has no parent container */
            else
            {
                gprintln("Simply not found");
                return null;
            }
        }
    }

    /**
    * Resolves dot-paths and non-dot paths
    * (both relative to a container)
    *
    * Example: Given c=clazz1 and name=clazz1 => result = clazz1
    * Example: Given c=clazz1 and name=x (x is within) => result = x
    * Example: Given c=clazz1 and name=clazz1.x => result = x
    * Example: Given c=clazz1 and name=clazz2.x => result = x
    */
    public Entity resolveBest(Container c, string name)
    {
        string[] path = split(name, '.');

        /**
        * If no dot
        *
        * Try and find `name` within c
        *
        * TODO: WOn't resolve a module
        */
        if(path.length == 1)
        {
            /* TODO: Add path[0], c.getName()) == modulle */

            /* TODO: This is for getting module entity */
            /* Check if the name, regardless of container, is root (Module) */
            // if(cmp(name, typeChecker.getModule().getName()) == 0)
            // {
            //     return typeChecker.getModule();
            // }

            Entity entityWithin = resolveUp(c, name);

            /* If `name` was in container `c` or above it */
            if(entityWithin)
            {
                return entityWithin;
            }
            /* If `name` was NOT found within container `c` or above it */
            else
            {
               return null;
            }
        }
        else
        {
            /* TODO: Add module name check here */

            /* If the root is the current container */
            if(cmp(path[0], c.getName()) == 0)
            {

                /* If only 1 left then just grab it */
                if(path.length == 2)
                {
                    Entity entityNext = resolveWithin(c, path[1]);
                    return entityNext;
                }
                /* Go deeper */
                else
                {
                    string newPath = name[indexOf(name, '.')+1..name.length];
                    Entity entityNext = resolveWithin(c, path[1]);

                    /* If null then not found */
                    if(entityNext)
                    {
                        Container containerWithin = cast(Container)entityNext;

                        if(entityNext)
                        {
                            /* TODO: Technically I could strip new root as we have the container */
                            /* TODO: The only reason I don't want to do that is the condition */
                            //newPath = newPath[indexOf(newPath, '.')+1..newPath.length];
                            return resolveBest(containerWithin, newPath);
                        }
                        else
                        {
                            return null;
                        }
                    }
                    else
                    {
                        return null;
                    }
                }
            }
            /* We need to search higher */
            else
            {
                /* TODO: Bug is we will never find top container */
                /* Check if the name of root is that of Module */
                if(cmp(typeChecker.getModule().getName(), path[0]) == 0)
                {
                    /* Root ourselves relative to the Module */
                    /* TODO: Don't serch for myModule class and ooga within */
                    /**
                    * TODO: Although the above should be impossible when we set usable names
                    * and make sure module name cannot be sed anywhere
                    */
                    /* TODO: Even if it could be because of this check it would be ignored */
                    /* TODO: This is what we want, but to avoid confusion we shouldn't allow the use of that name */
                    return resolveBest(typeChecker.getModule(), name);
                }

                Entity entityFound = resolveUp(c, path[0]);

                if(entityFound)
                {
                    Container con = cast(Container)entityFound;

                    if(con)
                    {
                        gprintln("fooook");
                        return resolveBest(con, name);
                    }
                    else
                    {
                        return null;
                    }
                }
                else
                {
                    /* TODO: We add module check here */

                    gprintln("killl me");
                    return null;
                }
            }

        }
    }
}