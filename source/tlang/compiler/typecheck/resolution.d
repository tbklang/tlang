module tlang.compiler.typecheck.resolution;

import tlang.compiler.typecheck.core;
import gogga;
import tlang.compiler.symbols.data;
import std.string;
import std.conv : to;
import tlang.compiler.core;
import std.string : format;
import niknaks.functional : Predicate, predicateOf;

/** 
 * The resolver provides a mechanism to
 * search the AST tree for all named
 * entities.
 *
 * It provides various different lookup
 * strategies for resolvbing recursively
 * at various different levels etc.
 */
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

    /** 
     * Performs a horizontal-level search of the given
     * `Container`, returning a found `Entity` when
     * the predicate supplied returns a positive
     * verdict on said entity, else returns `null`
     *
     * Params:
     *   currentContainer = the container to search
     * within
     *   predicate = the predicate to use
     * Returns: an `Entity` or `null`
     */
    public Entity resolveWithin(Container currentContainer, Predicate!(Entity) predicate)
    {
        Statement[] statements = currentContainer.getStatements();

        foreach(Statement statement; statements)
        {
            /* TODO: Only acuse parser not done yet */
            if(statement !is null)
            {
                Entity entity = cast(Entity) statement;

                if(entity)
                {
                    if(predicate(entity))
                    {
                        return entity;
                    }
                }
            }
        }

        return null;
    }

    /** 
     * Creates a closure that captures the name
     * requested and encodes a name-matching based
     * logic in it
     *
     * Params:
     *   nameToMatch = the name the closure predicate
     * should match to
     *
     * Returns: a `Predicate!(Entity)`
     */
    private static Predicate!(Entity) derive_nameMatch(string nameToMatch)
    {
        /**
         * A name-based search is simply something
         * that would use the below closure as
         * the searching predicate
         */
        bool nameMatch(Entity entity)
        {
            return cmp(entity.getName(), nameToMatch) == 0;
        }

        // TODO: Double check but yeah sure this will now
        // allocate `name` on heap to prevent stack overwrite
        // when called

        return &nameMatch;
    }

    /** 
     * Performs a horizontal-based search of then
     * provided `Container`, searching for any
     * `Entity` which matches the given name.
     *
     * Params:
     *   currentContainer = the container to
     * search within
     *   name = the name to search for
     * Returns: the `Entity` if found, else
     * `null`
     */
    public Entity resolveWithin(Container currentContainer, string name)
    {
        // Apply search with custom name-based matching predicate
        return resolveWithin(currentContainer, derive_nameMatch(name));


        // Statement[] statements = currentContainer.getStatements();

        // foreach (Statement statement; statements)
        // {
        //     /* TODO: Only acuse parser not done yet */
        //     if (statement !is null)
        //     {
        //         Entity entity = cast(Entity) statement;

        //         if (entity)
        //         {
        //             if (cmp(entity.getName(), name) == 0)
        //             {
        //                 return entity;
        //             }
        //         }
        //     }
        // }

        // return null;
    }

    /** 
     * Performs a horizontal-based search of the given
     * `Container`, returning the first `Entity` found
     * when a posotive verdict is returned from having
     * the provided predicate applied to it.
     *
     * If the verdict is `false` then we do not give
     * up immediately but rather recurse up the parental
     * tree searching the container of the current
     * container and applying the same logic.
     *
     * The stopping condition is when the current
     * container has no ancestral parent, then
     * we return `null`.
     *
     * Params:
     *   currentContainer = the starting container
     * to begin the search from
     *   predicate = the predicate to apply
     * Returns: an `Entity` or `null`
     */
    public Entity resolveUp(Container currentContainer, Predicate!(Entity) predicate)
    {
        /* Try to find the Entity wthin the current Container */
        gprintln(format("resolveUp(c=%s, pred=%s)", currentContainer, predicate));
        Entity entity = resolveWithin(currentContainer, predicate);
        gprintln(format("resolveUp(c=%s, pred=%s) within-search returned '%s'", currentContainer, predicate, entity));

        /* If we found it return it */
        if(entity)
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
            gprintln(format("resolveUp(c=%s, pred=%s) possible parent: %s", currentContainer, predicate, possibleParent));

            /* Can we go up */
            if(possibleParent)
            {
                return resolveUp(possibleParent, predicate);
            }
            /* If the current container has no parent container */
            else
            {
                gprintln(format("resolveUp(c=%s, pred=%s) Simply not found ", currentContainer, predicate));
                return null;
            }
        }
    }

    public Entity resolveUp(Container currentContainer, string name)
    {
        return resolveUp(currentContainer, derive_nameMatch(name));

        // // /* If given container is null */
        // // if(!currentContainer)
        // // {
        // //     return null;
        // // }

        // /* Try find the Entity within the current Contaier */
        // gprintln("resolveUp("~to!(string)(currentContainer)~", "~name~")");
        // Entity entity = resolveWithin(currentContainer, name);
        // gprintln("Certified 2008 financial crisis moment");
        // gprintln(entity);

        // /* If we found it return it */
        // if (entity)
        // {
        //     return entity;
        // }
        // /* If we didn't then try go up a container */
        // else
        // {
        //     /**
        //     * TODO: Make sure this condition holds
        //     *
        //     * So far all objects we have being used
        //     * of which are kind-of Containers are also
        //     * and ONLY also kind-of Entity's hence the
        //     * cast should never fail
        //     */
        //     assert(cast(Entity) currentContainer);
        //     Container possibleParent = (cast(Entity) currentContainer).parentOf();

        //     /* Can we go up */
        //     if (possibleParent)
        //     {
        //         return resolveUp(possibleParent, name);
        //     }
        //     /* If the current container has no parent container */
        //     else
        //     {
        //         gprintln("Simply not found");
        //         return null;
        //     }
        // }
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

    unittest
    {
        string input = "";
        string[] path = split(input, '.');
        assert(path.length == 0);
    }

    public Entity resolveBest(Container c, Predicate!(Entity) d)
    {
        // TODO: See how we would go about this

        /** 
         * For smething like this to work we must
         * extract the non-name-related logic from
         * below and code that.
         *
         * I believe what that would be is effectively,
         * a method which applies the predicate
         */



        return null;
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
        assert(path.length); // We must have _something_ here

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
            Program programC = cast(Program)c;

            // If you were asking just for the module
            // e.g. `simple_module`
            if(path.length == 1)
            {
                string moduleRequested = name;
                foreach(Module curMod; programC.getModules())
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

                foreach(Module curMod; programC.getModules())
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

    private struct SearchCtx
    {
        private Container ctnr;
        private Statement stmt;

        public Container container()
        {
            return this.ctnr;
        }

        public Statement statement()
        {
            return this.stmt;
        }
    }


    public auto findFrom(string what)(SearchCtx ctx, Predicate!(SearchCtx) predicate)
    {
        // // If starting node is `null`, return `null`
        // if(startingNode is null)
        // {
        //     return null;
        // }


        // // Construct context
        // // SearchCtx ctx = SearchCtx(startingNode.parentOf(), startingNode);
        // gprintln(format("ctx is: %s", ctx));

        // // If predicate is true then return
        // // what was requested
        // if(predicate(ctx))
        // {
        //     static if(what == "ctxStatement")
        //     {
        //         return ctx.statement();
        //     }
        //     else static if(what == "ctxContainer")
        //     {
        //         return ctx.container();
        //     }
        //     else
        //     {
        //         pragma(msg, "Unsupported requested return type '"~what~"'");
        //         static assert(false);
        //     }
        // }
        // // If predicate is false, then we should
        // // swim upwards
        // else
        // {

        //     SearchCtx ctxNew = SearchCtx()
        //     return findFrom!(what)(ctx.container(), predicate);
        // }

        
        return null;
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
