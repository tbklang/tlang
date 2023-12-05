module tlang.compiler.typecheck.resolution;

import tlang.compiler.typecheck.core;
import gogga;
import tlang.compiler.symbols.data;
import std.string;
import std.conv : to;
import tlang.compiler.core;

public final class Resolver
{
    /** 
     * The root of everything; the `Program`
     */
    private Program program;

    /** 
     * Associated TypeChecker engine
     */
    private TypeChecker typeChecker;

    /** 
     * Comnstructs a new resolver with the gievn
     * root program and the type checking instance
     *
     * Params:
     *   program = the root program
     *   typeChecker =  the type checker instance
     */
    this(Program program, TypeChecker typeChecker)
    {
        this.program = program;
        this.typeChecker = typeChecker;
    }

    /** 
     * Generate the absolute full path of the given Entity
     *
     * Params:
     *   entity = The Entity to generate the full absolute path for
     *
     * Returns: The absolute full path
     */
    public string generateNameBest(Entity entity)
    {
        string absoluteFullPath;
        
        assert(entity);

        /** 
         * Search till we get to the top-most Container
         * then generate a name relative to that with `generateName(topMostContainer, entity)`
         */
        Entity parentingEntity = entity;

        while(true)
        {
            parentingEntity = cast(Entity)parentingEntity.parentOf();

            if(parentingEntity.parentOf() is null)
            {
                break;
            }
        }

        absoluteFullPath = generateName(cast(Container)parentingEntity, entity);


        return absoluteFullPath;
    }


    /**
    * Given an Entity generate it's full path relative to a given
    * container, this is akin to `generateNameWithin()` in the
    * sense that it will fail if the entity prvided is not
    * contained by `relativeTo` - returning null
    */
    public string generateName(Container relativeTo, Entity entity)
    {
        // FIXME: (MODMAN) The relativeTo here (if we ever call with)
        // ... a program will obviously cause the assertion to fail
        // ... because Program's are not Entity(s) - the assertion
        // ... is in the inner call
        //
        // For that we must have a `getRoot` (use `findContainerOfType`
        // with the type set to `Module`) which resolves till it stops
        // at the top of the parenthood tree of `entity`, then we should
        // just early return `generateName_Internal(foundMod, entity)`
        //
        // Because as I said, a Program is not an Entity - IT HAS NO NAME!
        if(cast(Program)relativeTo)
        {
            Container potModC = findContainerOfType(Module.classinfo, entity);
            assert(potModC); // Should always be true (unless you butchered the AST)
            Module potMod = cast(Module)potModC;
            assert(potMod); // Should always be true (unless you butchered the AST)

            return generateName(potMod, entity);
        }

        string[] name = generateName_Internal(relativeTo, entity);
        string path;
        for (ulong i = 0; i < name.length; i++)
        {
            path ~= name[name.length - 1 - i];

            if (i != name.length - 1)
            {
                path ~= ".";
            }
        }

        return path;
    }

    private string[] generateName_Internal(Container relativeTo, Entity entity)
    {
        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity) relativeTo;
        assert(containerEntity);

        /**
        * If the Entity and Container are the same then
        * just returns its name
        */
        if (relativeTo == entity)
        {
            return [containerEntity.getName()];
        }
        /**
        * If the Entity is contained within the Container
        */
        else if (isDescendant(relativeTo, entity))
        {
            string[] items;

            Entity currentEntity = entity;
            do
            {
                items ~= currentEntity.getName();

                /**
                * TODO: Make sure this condition holds
                *
                * So far all objects we have being used
                * of which are kind-of Containers are also
                * and ONLY also kind-of Entity's hence the
                * cast should never fail
                */
                assert(cast(Entity) currentEntity.parentOf());
                currentEntity = cast(Entity)(currentEntity.parentOf());
            }
            while (currentEntity != relativeTo);

            /* Add the relative to container */
            items ~= containerEntity.getName();

            return items;
        }
        /* If not */
        else
        {
            //TODO: technically an assert should be here and the one in isDescdant removed
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
        if (c == e)
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
                gprintln("c isdecsenat: "~to!(string)(c));
                gprintln("currentEntity: "~to!(string)(currentEntity));
                gprintln("currentEntity(parent): "~to!(string)(currentEntity.parentOf()));

                /**
                * TODO: Make sure this condition holds
                *
                * So far all objects we have being used
                * of which are kind-of Containers are also
                * and ONLY also kind-of Entity's hence the
                * cast should never fail
                */
                assert(cast(Entity) currentEntity.parentOf());
                // FIXME: Enable this below whenever we have any sort of crash
                // (There is a case where we have it fail on `Variable (Ident: p, Type: int)`)
                gprintln("AssertFail Check: "~to!(string)(currentEntity));
                currentEntity = cast(Entity)(currentEntity.parentOf());

                if (currentEntity == c)
                {
                    return true;
                }
            }
            while (currentEntity);

            return false;
        }
    }

    public Entity resolveWithin(Container currentContainer, string name)
    {
        Statement[] statements = currentContainer.getStatements();

        foreach (Statement statement; statements)
        {
            /* TODO: Only acuse parser not done yet */
            if (statement !is null)
            {
                Entity entity = cast(Entity) statement;

                if (entity)
                {
                    if (cmp(entity.getName(), name) == 0)
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
        gprintln("resolveUp("~to!(string)(currentContainer)~", "~name~")");
        Entity entity = resolveWithin(currentContainer, name);
        gprintln("Certified 2008 financial crisis moment");
        gprintln(entity);

        /* If we found it return it */
        if (entity)
        {
            return entity;
        }
        /* If we didn't then try go up a container */
        else
        {
            /**
            * TODO: Make sure this condition holds
            *
            * So far all objects we have being used
            * of which are kind-of Containers are also
            * and ONLY also kind-of Entity's hence the
            * cast should never fail
            */
            assert(cast(Entity) currentContainer);
            Container possibleParent = (cast(Entity) currentContainer).parentOf();

            /* Can we go up */
            if (possibleParent)
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

    unittest
    {
        string input = "hello.world";
        string[] path = split(input, '.');
        assert(path.length == 2);
    }

    unittest
    {
        string input = "hello.";
        string[] path = split(input, '.');
        assert(path.length == 2);
    }

    unittest
    {
        string input = "hello";
        string[] path = split(input, '.');
        assert(path.length == 1);
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

        // FIXME: (MODMAN) Container can be a `Program`
        // ... (if we call it with that)
        // ... and the assertion below will fail
        // ... therefore we will have to take the 
        // ... name in such a case (should we even
        // ... be calling it like so)
        //
        // Infact this should probably only be
        // ...called relative to a Module, there
        // are only some cases where it makes sense
        // otherwise
        if(cast(Program)c)
        {
            gprintln("resolveBest: Container is program ("~to!(string)(c)~")");
            Program program = cast(Program)c;

            // If you were asking just for the module
            // e.g. `simple_module`
            if(path.length == 0)
            {
                string moduleRequested = name;
                foreach(Module curMod; program.getModules())
                {
                    gprintln("resolveBest(moduleHorizontal): "~to!(string)(curMod));
                    if(cmp(moduleRequested, curMod.getName()) == 0)
                    {
                        return curMod;
                    }
                }

                gprintln("resolveBest(Program root): Could not find module for DIRECT access", DebugType.ERROR);
                return null;
            }
            // If you were asking for some entity
            // anchored within a module
            // e.g.`simple_module.x`
            else
            {
                // First ensure a valid module name as anchor
                string moduleRequested = path[0];
                Container anchor;

                foreach(Module curMod; program.getModules())
                {
                    gprintln("resolveBest(moduleHorizontal): "~to!(string)(curMod));
                    if(cmp(moduleRequested, curMod.getName()) == 0)
                    {
                        anchor = curMod;
                        break;
                    }
                }

                // If we found the module
                // then do an anchored search
                // on the remaining path
                if(anchor)
                {
                    string remainingPath = join(path[1..$], ".");
                    return resolveBest(anchor, remainingPath);
                }
                // If we could not find the module
                else
                {
                    gprintln("resolveBest(Program root): Could not find module '"~moduleRequested~"' for ANCHORED access", DebugType.ERROR);
                    return null;
                }
            }
        }

        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity) c;
        assert(containerEntity);

        /**
        * If no dot
        *
        * Try and find `name` within c
        */
        if (path.length == 1)
        {
            /**
             * Check if the name, regardless of container,
             * matches any of the roots (modules attached
             * to this program)
             */
            foreach(Module curModule; this.program.getModules())
            {
                if(cmp(name, curModule.getName()) == 0)
                {
                    return curModule;
                }
            }

            Entity entityWithin = resolveUp(c, name);

            /* If `name` was in container `c` or above it */
            if (entityWithin)
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
            if (cmp(path[0], containerEntity.getName()) == 0)
            {

                /* If only 1 left then just grab it */
                if (path.length == 2)
                {
                    Entity entityNext = resolveWithin(c, path[1]);
                    return entityNext;
                }
                /* Go deeper */
                else
                {
                    string newPath = name[indexOf(name, '.') + 1 .. name.length];
                    Entity entityNext = resolveWithin(c, path[1]);

                    /* If null then not found */
                    if (entityNext)
                    {
                        Container containerWithin = cast(Container) entityNext;

                        if (entityNext)
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
                /**
                 * Check if the name is of one of the modules
                 * attached to the program
                 */
                foreach(Module curModule; this.program.getModules()) // TODO; Ensure `getModules()` is the correct call to use
                {
                    if(cmp(curModule.getName(), path[0]) == 0)
                    {
                        return resolveBest(curModule, name);
                    }
                }

                Entity entityFound = resolveUp(c, path[0]);

                if (entityFound)
                {
                    Container con = cast(Container) entityFound;

                    if (con)
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

    /** 
     * Given a type-of `Container` and a starting `Statement` (AST node) this will
     * swim upwards to try and find the first matching parent of which is of the given
     * type (exactly, not kind-of).
     *
     * Params:
     *   containerType = the type-of `Container` to look for
     *   startingNode = the starting AST node (as a `Statement`)
     * Returns: the found `Container`, or `null` if not found
     */
    public Container findContainerOfType(TypeInfo_Class containerType, Statement startingNode)
    {
        gprintln("findContainerOfType(TypeInfo_Class, Statement): StmtStart: "~to!(string)(startingNode));
        gprintln("findContainerOfType(TypeInfo_Class, Statement): StmtStart (type): "~to!(string)(startingNode.classinfo));

        // If the given AST objetc is null, return null
        if(startingNode is null)
        {
            return null;
        }
        // If the given AST object's type is of the type given
        else if(typeid(startingNode) == containerType)
        {
            // Sanity check: You should not be calling with a TypeInfo_Class referring to a non-`Container`
            assert(cast(Container)startingNode);
            return cast(Container)startingNode;
        }
        // If not, swim up to the parent
        else
        {
            gprintln("parent of "~to!(string)(startingNode)~" is "~to!(string)(startingNode.parentOf()));
            return findContainerOfType(containerType, cast(Statement)startingNode.parentOf());
        }
    }
}
