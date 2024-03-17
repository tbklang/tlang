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
     * Generate the absolute full path of the given
     * entity without specifying which anchor point
     * to use.
     *
     * This will climb the AST tree until it finds
     * the containing `Module` of the given entity
     * and then it will generate the name using
     * that as the anchor - hence giving you the
     * absolute path.
     *
     * Params:
     *   entity = The Entity to generate the full absolute path for
     *
     * Returns: The absolute full path
     */
    public string generateNameBest(Entity entity)
    {
        assert(entity);

        // Easiest way to do this is to find the
        // given entity's nearest container which
        // is a Module and then generate from there
        // as the anchor point
        Container entityMod = findContainerOfType(Module.classinfo, entity);

        return generateName(entityMod, entity);
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
     * Returns `true` entity `e` is `c` or is within 
     * (contained under `c`), `false` otherwise
     *
     * Params:
     *   c = the `Container` to check against
     *   e = the `Entity` to check if it belongs
     * to the container `c` either directly or
     * indirectly (or if it IS the container `c`)
     * Returns: `true` if so, `false` otherwise
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

                Container parentOfCurrent = currentEntity.parentOf();
                gprintln("currentEntity(parent): "~to!(string)(parentOfCurrent));

                // If the parent of the currentEntity
                // is what we were seraching for, then
                // yes, we found it to be a descendant
                // of it
                if(parentOfCurrent == c)
                {
                    return true;
                }

                // Every other case, use current entity's parent
                // as starting point and keep climbing
                //
                // This would also be null (and stop the seasrch
                // if we reached the end of the tree in a case
                // where the given container to anchor by iss
                // the `Program` BUT was not that of a valid one
                // that actually belonged to the same tree as
                // the starting node. This becomes `null` because
                // remember that a `Program` is not a kind-of `Entity`
                currentEntity = cast(Entity)(parentOfCurrent);
            }
            while (currentEntity);

            return false;
        }
    }

    /** 
     * Performs a horizontal-level search of the given
     * `Container`, returning a found `Entity` when
     * the predicate supplied returns a positive
     * verdict on said entity then we add an entry
     * to the ref parameter
     *
     * Params:
     *   currentContainer = the container to search
     * within
     *   predicate = the predicate to use
     */
    public void resolveWithin(Container currentContainer, Predicate!(Entity) predicate, ref Entity[] collection)
    {
        gprintln(format("resolveWithin(cntnr=%s) entered", currentContainer));
        Statement[] statements = currentContainer.getStatements();
        gprintln(format("resolveWithin(cntnr=%s) container has statements %s", currentContainer, statements));

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
                        collection ~= entity;               
                    }
                }
            }
        }
    }

    /** 
     * Performs a horizontal-level search of the given
     * `Container`, returning a found `Entity` when
     * the predicate supplied returns a positive
     * verdict on said entity then we return it.
     *
     * Params:
     *   currentContainer = the container to search
     * within
     *   predicate = the predicate to use
     * Returns: an `Entity` if found else `null`
     */
    public Entity resolveWithin(Container currentContainer, Predicate!(Entity) predicate)
    {
        Entity[] foundEnts;
        resolveWithin(currentContainer, predicate, foundEnts);
        gprintln(format("foundEnts: %s", foundEnts));

        return foundEnts.length ? foundEnts[0] : null;
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
            bool result = cmp(entity.getName(), nameToMatch) == 0;
            gprintln(format("nameMatch(left=%s, right=%s) result: %s", nameToMatch, entity.getName(), result));
            return result;
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
     * When a match is found we return
     * immediately.
     *
     * Params:
     *   currentContainer = the container to
     * search within
     *   name = the name to search for
     * Returns: the found `Entity` or
     * `null` nothing was found
     */
    public Entity resolveWithin(Container currentContainer, string name)
    {
        // Apply search with custom name-based matching predicate
        gprintln(format("resolveWithin(cntnr=%s, name=%s) entering with predicate", currentContainer, name));
        return resolveWithin(currentContainer, derive_nameMatch(name));
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
        /**
         * If nothing was found (and current container is `Program`)
         * then there is no further up we can go and we must end the
         * search with no result
         */
        else if(cast(Program)currentContainer)
        {
            gprintln
            (
                format
                (
                    "resolveUp(cntr=%s, pred=%s) Entity was not found and we cannot crawl any further up as we are at the Program container now",
                    currentContainer,
                    predicate
                )
            );

            return null;
        }
        /* If we didn't then try go up a container */
        else
        {
            /**
            * We will ONLY ever have a `Container`
            * here of which is ALSO an `Entity`.
            */
            assert(cast(Entity)currentContainer);
            Container possibleParent = (cast(Entity) currentContainer).parentOf();

            gprintln(format("resolveUp(c=%s, pred=%s) cur container typeid: %s", currentContainer, predicate, currentContainer));
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

    /** 
     * Performs a horizontal-based search of the given
     * `Container`, returning the first `Entity` found
     * when such ne is found with a name matching the
     * one provided
     *
     * If not found within the given container then we
     * do not give up immediately but rather recurse
     * up the parental tree searching the container
     * of the current container and applying the same logic.
     *
     * The stopping condition is when the current
     * container has no ancestral parent, then
     * we return `null`.
     *
     * Params:
     *   currentContainer = the starting container
     * to begin the search from
     *   name = the name of the `Entity` to search
     * for
     * Returns: an `Entity` or `null`
     */
    public Entity resolveUp(Container currentContainer, string name)
    {
        return resolveUp(currentContainer, derive_nameMatch(name));
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
        gprintln(format("resolveBest(cntnr=%s, name=%s) Entered", c, name));
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
            //
            // Note that this won't consider doing
            // a find of the entity in any other module
            // if the path = ['g']. The reason for that is
            // because a search rooted at the `Program`
            // could find such an entity in ANY of the
            // modules if we added such support but that
            // would be kind of useless
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

                gprintln("resolveBest(moduleHoritontal) We found nothing and will not go down from Program to any Module[]. You probably did a rooted search on the Program for a bnon-Module entity, didn't ya?", DebugType.ERROR);
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

        gprintln(format("resolveBest(cntr=%s,name=%s) path = %s", c, name, path));

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
                        gprintln(format("About to search for name='%s' in module %s", name, curModule));
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
                        gprintln("also a kill me");
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

version(unittest)
{
    import std.file;
    import std.stdio;
    import tlang.compiler.lexer.core;
    import tlang.compiler.lexer.kinds.basic : BasicLexer;
    import tlang.compiler.typecheck.core;
    import misc.exceptions : TError;
}


/**
 * Tests out various parts of the
 * `Resolver`
 */
unittest
{
    string sourceCode = `
module resolution_test_1;

int g;
`;

    File dummyFile;
    Compiler compiler = new Compiler(sourceCode, "legitidk.t", dummyFile);

    try
    {
        compiler.doLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    try
    {
        compiler.doParse();
        Program program = compiler.getProgram();

        // There is only a single module in this program
        Module modulle = program.getModules()[0];

        /* Module name must be resolution_test_1 */
        assert(cmp(modulle.getName(), "resolution_test_1")==0);
        TypeChecker tc = new TypeChecker(compiler);

        // Now try to find the variable `d` by starting at the program-level
        // this SHOULD fail as it should NOT be allowed
        Entity var = tc.getResolver().resolveBest(program, "g");
        assert(var is null);

        // Try to find the variable `d` by starting at the module-level
        var = tc.getResolver().resolveBest(modulle, "g");
        assert(var);
        assert(cast(Variable)var); // Ensure it is a variable

        // We should be able to do a rooted search for a module, however,
        // at the Program level
        Entity myModule = tc.getResolver().resolveBest(program, "resolution_test_1");
        assert(myModule);
        assert(cast(Module)myModule); // Ensure it is a Module

        // The `g` should be a descendant of the module and the module of the program
        assert(tc.getResolver().isDescendant(cast(Container)myModule, var));
        assert(tc.getResolver().isDescendant(cast(Container)program, myModule));

        // Lookup `resolution_test_1.g` but anchored from the `Program`
        Entity varAgain = tc.getResolver().resolveBest(program, "resolution_test_1.g");
        assert(varAgain);
        assert(cast(Variable)varAgain); // Ensure it is a Variable


        // Generate the name from the program as the anchor
        string nameFromProgram = tc.getResolver().generateName(program, var);
        gprintln(format("nameFromProgram: %s", nameFromProgram));
        assert(nameFromProgram == "resolution_test_1.g");

        // Generate the name from the module as the anchor (should be same as above)
        string nameFromModule = tc.getResolver().generateName(cast(Container)myModule, var);
        gprintln(format("nameFromModule: %s", nameFromModule));
        assert(nameFromModule == "resolution_test_1.g");

        // Generate absolute path of the entity WITHOUT an anchor point
        string bestName = tc.getResolver().generateNameBest(var);
        gprintln(format("bestName: %s", bestName));
        assert(bestName == "resolution_test_1.g");
    }
    catch(TError e)
    {
        assert(false);
    }
}