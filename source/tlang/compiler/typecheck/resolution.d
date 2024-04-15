module tlang.compiler.typecheck.resolution;

import tlang.compiler.typecheck.core;
import tlang.misc.logging;
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
     * Constructs a new resolver with the given
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
     * What this will do is call `generateName(Container, Entity)`
     * with the container set to the `Program`,
     * this will therefore cause the intended
     * behavior described above - see the aforementioned
     * method for the reason as to why this works
     * out.
     *
     * This will climb the AST tree until it finds
     * the containing `Module` of the given entity
     * and then it will generate the name using
     * that as the anchor - hence giving you the
     * absolute path (because remember, a `Program`
     * has no name, next best is the `Module`).
     *
     * Params:
     *   entity = The Entity to generate the full absolute path for
     *
     * Returns: The absolute full path
     */
    public string generateNameBest(Entity entity)
    {
        assert(entity);
        return generateName(this.program, entity);
    }

    /** 
     * Given an entity and a container this will
     * generate the entity's full path relative
     * to the given container.
     *
     * A special case is when the container is a
     * `Program`, in that case the entity's containing
     * `Module` will be found and the name will be
     * generated relative to that. Since `Program`'s
     * have no names, doing such a call gives you
     * the absolute (full path) of the entity within
     * the entire program as the `Module` is the
     * second highest in the AST tree and first
     * `Entity`-typed object, meaning first "thing"
     * with a name.
     *
     * Params:
     *   relativeTo = the container to generate relative
     * to
     *   entity = the entity to generate a name for
     * Returns: the generated path
     */
    public string generateName(Container relativeTo, Entity entity)
    {
        assert(relativeTo);
        assert(entity);

        // Special case (see doc)
        if(cast(Program)relativeTo)
        {
            Container potModC = findContainerOfType(Module.classinfo, entity);
            assert(potModC); // Should always be true (unless you butchered the AST)
            Module potMod = cast(Module)potModC;
            assert(potMod); // Should always be true (unless you butchered the AST)

            return generateName(potMod, entity);
        }

        string[] name = generateName0(relativeTo, entity);
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

    /** 
     * Generates the components of the path from
     * a given entity up to (and including) the
     * given container. The latter implies that
     * the given `Container` must also be a kind-of
     * `Entity` such that a name can be generated
     * from it.
     *
     * Params:
     *   relativeTo = the container to generate
     * up to (inclusively)
     *   entity = the entity to start at
     * Returns: an array of the named segments
     * from the container-to-entity appearing in
     * a left-to-right fashion. `null` is returned
     * in the case that the given entity has no
     * relation at all to the given container.
     */
    private string[] generateName0(Container relativeTo, Entity entity)
    {
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
                 * So far all objects we have being used
                 * of which are kind-of Containers are also
                 * and ONLY also kind-of Entity's hence the
                 * cast should never fail.
                 * 
                 * This method is never called with,
                 * for example, a `Program` relativeTo.
                 */
                assert(cast(Entity) currentEntity.parentOf());
                currentEntity = cast(Entity)(currentEntity.parentOf());
            }
            while (currentEntity != relativeTo);

            /* Add the relative to container */
            items ~= containerEntity.getName();

            return items;
        }
        /** 
         * If not
         */
        else
        {
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
                DEBUG
                (
                    format("c isdecsenat: %s", c)
                );
                DEBUG
                (
                    format("currentEntity: %s", currentEntity)
                );

                Container parentOfCurrent = currentEntity.parentOf();
                DEBUG
                (
                    format("currentEntity(parent): %s", parentOfCurrent)
                );

                // If the parent of the currentEntity
                // is what we were searching for, then
                // yes, we found it to be a descendant
                // of it
                if(parentOfCurrent == c)
                {
                    return true;
                }

                // Every other case, use current entity's parent
                // as starting point and keep climbing
                //
                // This would also be null (and stop the search
                // if we reached the end of the tree in a case
                // where the given container to anchor by is
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
        DEBUG
        (
            format
            (
                "resolveWithin(cntnr=%s) entered",
                currentContainer
            )
        );
        Statement[] statements = currentContainer.getStatements();
        DEBUG
        (
            format
            (
                "resolveWithin(cntnr=%s) container has statements %s",
                currentContainer,
                statements
            )
        );

        foreach(Statement statement; statements)
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
        DEBUG(format("foundEnts: %s", foundEnts));

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
            DEBUG(format("nameMatch(left=%s, right=%s) result: %s", nameToMatch, entity.getName(), result));
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
        DEBUG(format("resolveWithin(cntnr=%s, name=%s) entering with predicate", currentContainer, name));
        return resolveWithin(currentContainer, derive_nameMatch(name));
    }

    /** 
     * Performs a horizontal-based search of the given
     * `Container`, returning the first `Entity` found
     * when a positive verdict is returned from having
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
        /* Try to find the Entity within the current Container */
        DEBUG
        (
            format
            (
                "resolveUp(c=%s, pred=%s)",
                currentContainer,
                predicate
            )
        );
        Entity entity = resolveWithin(currentContainer, predicate);
        DEBUG
        (
            format
            (
                "resolveUp(c=%s, pred=%s) within-search returned '%s'",
                currentContainer,
                predicate,
                entity
            )
        );

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
            DEBUG
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

            DEBUG
            (
                format
                (
                    "resolveUp(c=%s, pred=%s) cur container typeid: %s",
                    currentContainer,
                    predicate,
                    currentContainer
                )
            );
            DEBUG
            (
                format
                (
                    "resolveUp(c=%s, pred=%s) possible parent: %s",
                    currentContainer,
                    predicate,
                    possibleParent
                )
            );

            /* Can we go up */
            if(possibleParent)
            {
                return resolveUp(possibleParent, predicate);
            }
            /* If the current container has no parent container */
            else
            {
                DEBUG
                (
                    format
                    (
                        "resolveUp(c=%s, pred=%s) Simply not found ",
                        currentContainer,
                        predicate
                    )
                );
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

    /** 
     * This will do a best effort search starting
     * for an entity with the given name. The search
     * will start from the given container and
     * perform a search within it, in the case no
     * such entity is found there then it will
     * recurse upwards, stopping when you reach
     * the program-level.
     *
     * This also handles special cases such as
     * dotted-paths, it can decode them and follow
     * the trail to the intended entity.
     *
     * In the case that the container given
     * is a `Program` then each name must
     * either be solely a module name or
     * a dotted-path beginning with one. In
     * this mode nothing else is accepted,
     * it effectively an absolute downwards
     * (rather than potentially upwards
     * search).
     *
     * Params:
     *   c = the starting container
     *   name = the name 
     * Returns: an `Entity` if found, otherwise
     * `null`
     */
    public Entity resolveBest(Container c, string name)
    {
        DEBUG
        (
            format
            (
                "resolveBest(cntnr=%s, name=%s) Entered",
                c,
                name
            )
        );
        string[] path = split(name, '.');
        assert(path.length); // We must have _something_ here

        // Infact this should probably only be
        // ...called relative to a Module, there
        // are only some cases where it makes sense
        // otherwise
        if(cast(Program)c)
        {
            DEBUG
            (
                format
                (
                    "resolveBest: Container is program (%s)",
                    c
                )
            );
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
                    DEBUG
                    (
                        format
                        (
                            "resolveBest(moduleHorizontal): %s",
                            curMod
                        )
                    );
                    if(cmp(moduleRequested, curMod.getName()) == 0)
                    {
                        return curMod;
                    }
                }

                ERROR
                (
                    "resolveBest(moduleHoritontal) We found nothing and will not go down from Program to any Module[]. You probably did a rooted search on the Program for a bnon-Module entity, didn't ya?"
                );
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
                    DEBUG
                    (
                        format
                        (
                            "resolveBest(moduleHorizontal): %s",
                            curMod
                        )
                    );
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
                    ERROR
                    (
                        format
                        (
                            "resolveBest(Program root): Could not find module '%s' for ANCHORED access",
                            moduleRequested
                        )
                    );
                    return null;
                }
            }
        }

        /**
         * All objects that implement Container so far
         * are also Entities (hence they have a name).
         *
         * The above is ONLY true except when you
         * have a `Program` BUT we handle the case
         * whereby `c` is a `Program` above, hence
         * meaning that this code is unreachable in
         * such a case and therefore safe.
         */
        Entity containerEntity = cast(Entity) c;
        assert(containerEntity);
        DEBUG
        (
            format
            (
                "resolveBest(cntr=%s,name=%s) path = %s",
                c,
                name,
                path
            )
        );

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
                foreach(Module curModule; this.program.getModules())
                {
                    if(cmp(curModule.getName(), path[0]) == 0)
                    {
                        DEBUG
                        (
                            format
                            (
                                "About to search for name='%s' in module %s",
                                name,
                                curModule
                            )
                        );
                        return resolveBest(curModule, name);
                    }
                }

                Entity entityFound = resolveUp(c, path[0]);

                if (entityFound)
                {
                    Container con = cast(Container) entityFound;

                    if (con)
                    {
                        DEBUG("fooook");
                        return resolveBest(con, name);
                    }
                    else
                    {
                        DEBUG("also a kill me");
                        return null;
                    }
                }
                else
                {
                    DEBUG("killl me");
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
        DEBUG
        (
            format
            (
                "findContainerOfType(TypeInfo_Class, Statement): StmtStart: %s",
                startingNode
            )
        );
        DEBUG
        (
            format
            (
                "findContainerOfType(TypeInfo_Class, Statement): StmtStart (type): %s",
                startingNode.classinfo
            )
        );

        // If the given AST object is null, return null
        if(startingNode is null)
        {
            return null;
        }
        // If the given AST object's type is of the type given
        else if(typeid(startingNode) == containerType)
        {
            // Sanity check: You should not be calling
            // with a TypeInfo_Class referring to a non-`Container`
            assert(cast(Container)startingNode);
            return cast(Container)startingNode;
        }
        // If not, swim up to the parent
        else
        {
            DEBUG
            (
                format
                (
                    "parent of %s is %s",
                    startingNode,
                    startingNode.parentOf()
                )
            );
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
    import tlang.misc.exceptions : TError;
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
        DEBUG(format("nameFromProgram: %s", nameFromProgram));
        assert(nameFromProgram == "resolution_test_1.g");

        // Generate the name from the module as the anchor (should be same as above)
        string nameFromModule = tc.getResolver().generateName(cast(Container)myModule, var);
        DEBUG(format("nameFromModule: %s", nameFromModule));
        assert(nameFromModule == "resolution_test_1.g");

        // Generate absolute path of the entity WITHOUT an anchor point
        string bestName = tc.getResolver().generateNameBest(var);
        DEBUG(format("bestName: %s", bestName));
        assert(bestName == "resolution_test_1.g");
    }
    catch(TError e)
    {
        assert(false);
    }
}