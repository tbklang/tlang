## Resolution

Once the parser has constructed an AST tree for us what we have is then a tree of nodes with nested nodes and nested nodes of nodes, so on... . This is great, but we need to be able to search this tree for certain things we may want to find - perhaps by _some predicate_ such as searching by **name**. All of this is made possible by the _resolver_.

### Containers, programs and modules

Before we examine the resolver's API and how to use it it is worth understanding the main important types that play a big role in the resolution process.

The interfaces of importance:

1. `Container`
    * Anything which is a `Container` will have methods allowing one to add `Statement`(s) to its body and retrieve all of said added `Statement`(s)
    * It also as of recently implies that methods from the `MStatementSearchable` and `MStatementReplaceable` interfaces are available as well - but those won't be covered here as they are nopt important for the ase functionality

The concrete types of importance:

1. `Program`
    * A `Program` holds multiple `Module`(s)
    * It is a kind-of `Container` **but NOT** any sort of `Statement` at all
2. `Module`
    * It is a kind-of `Container` and an `Entity`
3. `Entity`
    * You would have seen this earlier, anything which is an entity has a _name_ associated with it

#### Container API

Let us quickly provide a breakdown of what methods the `Container` interface type requires one to have implemented and readily available for usage on the _implementing type_.


| Method                       | Return type | Description                |
|------------------------------|-------------|----------------------------|
| `addStatement(Statement)`    | `void`      | Appends the given statement to this container's body |
| `addStatements(Statement[])` | `void`      | Appends the list of statements (in order) to this container's body |
| `getStatements()`            | `Statement[]` | Returns the body of this container |

> We mentioned that the `Container` interface also implements the `MStatementSearchable` and `MStatementReplaceable` interfaces. Those **are** important but their applicability is not within the resolution process at all, so they are excluded from the above method listing.

#### Program API

The _program_ holds a bunch of _modules_ as its _body statements_ (hence being a `Container` type). A program,, unlike a module, is not an `Entity` - meaning it has no name associated with it **but** it is the root of the AST tree.

| Method                                | Return type | Description           |
|---------------------------------------|-------------|-----------------------|
| `getModules()`                        | `Module[]`  | Returns the list of all modules which make up this program. |
| `setEntryModule(ModuleEntry, Module)` | `void`      | Given a module entry this will assign (map) a module to it. Along with doing this the incoming module shall be added to the body of this `Program` and this module will have its parent set to said `Program`. |
| `markEntryAsVisited(ModuleEntry)`     | `void`      | Marks the given entry as present. This effectively means simply adding the name of the incoming module entry as a key to the internal map but without it mapping to a module in particular. |
| `isEntryPresent(ModuleEntry)`         | `bool`      | Check if the given module entry is present. This is based on whether a module entry within the internal map is present which has a name equal to the incoming entry. |


Some of the methods above are related to the `Container`-side of the `Program` type. These methods are useful once the `Program` is already fully constructed, i.e. all parsing has been completed.

Some of the _other_ methods relating to the `markEntryAsVisited(ModuleEntry)` and so forth have to do with the mechanism by which the parser adds new modules to the program during parsing and ensures that no cycles are traversed (i.e. when a module is already being visited it should not be visited again).

### The _resolver_

Now that we have a good idea of the types involved we can take a look at the API which the resolver has to offer and how it may be used in order to generate names of _entities_ and perform the resolution of _entities_.

Let's first take a look at the constructor that the `Resolver` has:

```d
this
(
    Program program,
    TypeChecker typeChecker
)
```

This constructs a new resolver with the given root program and the type checking instance. This implies you must have performed parsing, constructed a `TypeChecker` and **only then** could you instantiate a resolver.

### Name resolution

Now that we know how to construct a resolver, let's see what methods it makes available to every component from the `TypeChecker` (as it is constructed here) and onwards.

The first set of methods relate to the name generation of entities in the AST tree.

| Method                    | Return type | Description                           |
|---------------------------|-------------|---------------------------------------|
| `isDescendant(Container, Entity)` | `bool` | Returns `true` entity `e` is `c` or is within  (contained under `c`), `false` otherwise |
| `generateName0(Container, Entity)` | `string[]` | Generates the components of the path from a given entity up to (and including) the given container. The latter implies that the given `Container` must also be a kind-of `Entity` such that a name can be generated from it. |
| `generateNameBest(Entity)`| `string`    | Generate the absolute full path of the given entity without specifying which anchor point to use. |
| `generateName(Container, Entity)` | `string` |  Given an entity and a container this will generate the entity's full path relative to the given container. If the container is a `Program` then the absolute name of the entity is derived. |

#### How `isDescendant(Container, Entity)` works

The first check we do is an obvious one, check if the provided entity is equal to that of the provided container, in that case it is a descendant by the rule.

```d
/**
 * If they are the same
 */
if (c == e)
{
    return true;
}
```

If this is _not_ the case then we check the ancestral relationship by traversing from the entity upwards.

We start off with this loop variable for our do-while loop:

```d
Entity currentEntity = e;
```

**Steps**:

The process of checking for descendance is now described and the actual implementation will follow.

1. At each iteration we obtain `currentEntity`'s parent by using `parentOf()`, we store this as `parentOfCurrent`
2. _If_ the `parentOfCurrent` is equal to the given container then we exit and return `true`. This is the case whereby the  direct parent is found.
3. _If not_, then...
    a. Every other case, use current entity's parent as starting point and keep climbing
    b. If no match is found in the intermediary we will eventually climb to the `Program` node. Since a `Program` _is_ a `Container` but _is **not**_ an `Entity` it will fail to cast and `currentEntity` will be `null`, hence exiting the loop and returning with `false`.

```d
do
{
    gprintln
    (
        format("c isdecsenat: %s", c)
    );
    gprintln
    (
        format("currentEntity: %s", currentEntity)
    );

    Container parentOfCurrent = currentEntity.parentOf();
    gprintln
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
```

#### How `generateNameBest(Entity)` works

The definition of this method is suspiciously simple:

```d
public string generateNameBest(Entity entity)
{
    assert(entity);
    return generateName(this.program, entity);
}
```

So what's going on? Well...

What this will do is call `generateName(Container, Entity)` with the container set to the `Program`, this will therefore cause the intended behavior described above - see the aforementioned method for the reason as to why this works out.
 
This will climb the AST tree until it finds the containing `Module` of the given entity and then it will generate the name using that as the anchor - hence giving you the absolute path (because remember, a `Program` has no name, next best is the `Module`).

#### How `generateName(Container, Entity)` works

The definition of this method is where the real complexity is housed. This also accounts for how the previous method, `generateNameBest(Entity)`, is implemented.

Firstly we ensure that both arguments are non-`null` with:

```d
assert(relativeTo);
assert(entity);
```

A special case is when the container is a `Program`, in that case the entity's containing `Module` will be found and the name will be generated relative to that. Since `Program`'s have no names, doing such a call gives you the absolute (full path) of the entity within the entire program as the `Module` is the second highest in the AST tree and first `Entity`-typed object, meaning first "thing" with a name.

```d
if(cast(Program)relativeTo)
{
    Container potModC = findContainerOfType(Module.classinfo, entity);
    assert(potModC); // Should always be true (unless you butchered the AST)
    Module potMod = cast(Module)potModC;
    assert(potMod); // Should always be true (unless you butchered the AST)

    return generateName(potMod, entity);
}
```

Given an entity and a container this will generate the entity's full path relative to the given container. This means calling `generateName0(Container, Entity)` and then joining each path element with a period.

```d
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
```

Once `path` is calculated we then finally return with it.

#### How `generateName0(Container, Entity)` works

Let's first look at how `generateName0(Container relativeTo, Entity entity)` is implemented. The idea behind this method is to generate an array of strings, i.e. `string[]`, which contains the highest node in the hierachy to the lowest node (then given entity) from left to right respectively.


As mentioned the given container, `relativeTo`, has to be a kind-of `Entity` as well such that a name can be generated for it, hence we ensure that the developer is not misusing it with the first check:

```d
Entity containerEntity = cast(Entity) relativeTo;
assert(containerEntity);
```

**Steps**:

1. The first check we then do is to see whether or not the `relativeTo == entity`
    a. _If so_, then we simply return a singular path element of `containerEntity.getName()`
2. The next check is to check whether or not the given entity is a descendant, either directly or indirectly, of the given container
    a. _If so_, then we begin generating the elements by swimming up the ancestor tree, stopping once the `relativeTo` is reached
3. The last check, if neither checks $1$ or $2$ were true, is to return `null` (an empty array)


The above steps are shown now below in their code form:

```d
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
```


### Entity resolution

The second set of methods relate to the resolution facilities made available which allow one to search for entities based on various different sorts of custom _predicates_ and by name.

| Method                    | Return type | Description                           |
|---------------------------|-------------|---------------------------------------|
| `resolveWithin(Container, Predicate!(Entity), ref Entity[])` | `void` | Performs a horizontal-level search of the given `Container`, returning a found `Entity` when the predicate supplied returns a positive verdict on said entity then we add an entry to the ref parameter |
| `resolveWithin(Container, Predicate!(Entity))` | `Entity` | Performs a horizontal-level search of the given `Container`, returning a found `Entity` when the predicate supplied returns a positive verdict on said entity then we return it. |
| `resolveUp(Container, Predicate!(Entity))` | `Entity` | Performs a horizontal-based search of the given `Container`, returning the first `Entity` found when a positive verdict is returned from having the provided predicate applied to it. If the verdict is `false` then we do not give up immediately but rather recurse up the parental tree searching the container of the current container and applying the same logic. |
| `resolveBest(Container, string)` | `Entity` | This will do a best effort search starting for an entity with the given name. The search will start from the given container and perform a search within it, in the case no such entity is found there then it will recurse upwards, stopping when you reach the program-level. This also handles special cases such as dotted-paths, it can decode them and follow the trail to the intended entity. In the case that the container given is a `Program` then each name must either be solely a module name or a dotted-path beginning with one. In this mode nothing else is accepted, it effectively an absolute downwards (rather than potentially upwards search). |
| `findContainerOfType(TypeInfo_Class, Statement)` | `Container` | Given a type-of `Container` and a starting `Statement` (AST node) this will swim upwards to try and find the first matching parent of which is of the given type (exactly, not kind-of). |

Only the important methods here will be mentioned. Methods pertaining to certain single-item return and predicate generation will not. For those please go examine the source code; see `resolution.d` for those codes.

#### How resolution _within_ works

The method `resolveWithin(Container, Predicate!(Entity), ref Entity[] collection)` is responsible for providing a facility where by a given predicate can be applied to all entities available at the immediate level of the given container.
 
With this understanding one can imagine that the implementation if rather simple then:

```d
gprintln
(
    format
    (
        "resolveWithin(cntnr=%s) entered",
        currentContainer
    )
);
Statement[] statements = currentContainer.getStatements();
gprintln
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
```

Simply iterate over all _statements_ present within the container (immediately, not considering nested one) and apply the predicate to each. If a match is found then add it to the `collection`, otherwise continue iterating.

#### How resolving _upwards_ works

The method `resolveUp(Container currentContainer, Predicate!(Entity) predicate)` performs a horizontal-based search of the given `Container`, returning the first `Entity` found when a positive verdict is returned from having the provided predicate applied to it. We can see this below:

```d
/* Try to find the Entity within the current Container */
gprintln
(
    format
    (
        "resolveUp(c=%s, pred=%s)",
        currentContainer,
        predicate
    )
);
Entity entity = resolveWithin(currentContainer, predicate);
gprintln
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
```

If the verdict is `false` _and_ the `currentContainer` is a kind-of `Program` then it means that there is no further up we can go and we must return `null`:

```d
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
```

However if the verdict is `false` but the `currentContainer` _is **not**_ a kind-of `Program` then we do not give up immediately but rather recurse up the parental tree searching the container of the current container and applying the same logic.

```d
/**
 * We will ONLY ever have a `Container`
 * here of which is ALSO an `Entity`.
 */
assert(cast(Entity)currentContainer);
Container possibleParent = (cast(Entity) currentContainer).parentOf();

gprintln
(
    format
    (
        "resolveUp(c=%s, pred=%s) cur container typeid: %s",
        currentContainer,
        predicate,
        currentContainer
    )
);
gprintln
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
    gprintln
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
```

#### How _best-effort_ resolution works

Best effort resolution is now described in this section. The method of concern for this is `resolveBest(Container c, string name)`.

**Steps**:

1. We first obtain the `path` as a `string[]` by splitting the incoming `name` by any periods present (`.`s)
2. _If_ the container `c` is a kind-of `Program` _then_...
    a. _If_ the `path` is a single element
        i.Search for a module with the name of `path[0]`
    b. _If_ the `path` is more than a single element then we take it that `path[0]` is the name of a module, we first search for that
        i. _If **not** found_ we return `null`
        ii. _If found_ we then call `resolveBest(moduleFound, join(path[1..$], '.')`, so we re-anchor our search based on the module as the container node for the recursive call and the rest of the search path is handed off to the nested call.
3. _If **not**_ and we have a single element in the `path` then we have a few more checks which follow
    a. We check if any of the _modules_ within the current _program_ matches the name
    b. _If_ no match is found _then_ we try to resolve the `name` (in other words `path[0]`) upwards
4. _If_ the `path` has more than one element
    a. _If_ `path[0]` refers to the container entity `c` then...
        i. _If_ there is only one element left, namely, `path[1]`, then we return with the result of calling `resolveWithin(c, path[1])`.
        ii. _If_ there are more than two elements then what we effectively do is these several steps. First, we check that there is an entity at `path[1]` by resolving it against `c` with `resolveWithin(c, path[1])`; if `null` we then return `null`, else we continue and call the found entity `entityNext`. Then we calculate as such, if the path was `x.y.z` then we make a `newPath` containing `y.z`. We now will resolve the `newPath` (the `y.z`) against `entityNext` (which we cast to a `Container` and ensure it is possible and call it `containerWithin`); this is accomplished with `resolveBest(containerWithin, newPath)`. Thus setting in motion the path walking recursive nature of this part of the algorithm.
    b. _If_ `path[0]` does **not** refer to the container entity `c`, then...
        i. First we check if the `path[0]` matches the name of any _module_ attached to the _current program_. If a match is found then we return with a call to `resolveBest(curModule, name)` and let it handle that. We do this so that module names are **always treated as absolute** and hence can always be referenced, unlike other containers which can have duplicate names if distanced away by at least one non-name-sharing container.
        ii. If a module name match _is **not**_ found then we attempt the following. We try to find an entity named by `path[0]` by resolving upwards, if we _do **not**_ find one, we return `null`, _else_ if we do then: We will use the found entity as a container called `con` and then do a `resolveBest(con, name)` in order to try and find it. This effectively is a step to find the nearest anchoring point (as `c` clearly isn't it) and then start the search from there.

The code for this is shown below. Note that it is quite a hefty piece of code but it does after all entail the above process.

```{.d .numberLines}
gprintln
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
    gprintln
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
            gprintln
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

        gprintln
        (
            "resolveBest(moduleHoritontal) We found nothing and will not go down from Program to any Module[]. You probably did a rooted search on the Program for a bnon-Module entity, didn't ya?",
            DebugType.ERROR
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
            gprintln
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
            gprintln
            (
                format
                (
                    "resolveBest(Program root): Could not find module '%s' for ANCHORED access",
                    moduleRequested
                ),
                DebugType.ERROR
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
gprintln
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
                gprintln
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
            gprintln("killl me");
            return null;
        }
    }
}
```

#### How finding a container of a concrete type works

It is sometimes of use to be able to find a _container_ of a _given type_. This is something the other methods do not really consider, for them the _container anchoring point_ and the _name_ are well known. There are however cases whereby one may one want to find a _container_ of a certain type given a starting _statement_ - this is what this method provides.

Taking a look at the method definition below:

```d
Container findContainerOfType
(
    TypeInfo_Class containerType,
    Statement startingNode
)
```

**Steps**:

1. _If_ the `startingNode` _is_ `null` then we return with `null`
2. _If_ the `typeid(startingNode)`, that is the actual type of `startingNode`, is equal to that of the `containerType` then we return the `startingNode` casted to a `Container`. This is a match on first-call with no swimming upwards.
3. _Else_ we find the _parent of_ the `startingNode` and recurse to this method using `findContainerOfType(containerType, cast(Container)startingNode.parentOf())`. This is a case of us finding the starting node's parent, and then re-applying the logic, hence swimming up in hopes we find the match somewhere above.

This is a relatively simple algorithm and the implementation is shown below:

```{.d .numberLines}
gprintln
(
    format
    (
        "findContainerOfType(TypeInfo_Class, Statement): StmtStart: %s",
        startingNode
    )
);
gprintln
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
    gprintln
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
```

### Worked examples

Given a program with a single module `resolution_test_1` as follows:

```d
string sourceCode = `
module resolution_test_1;

int g;
`
```

We then setup such a relationship (for the sake of the test):

```d
File dummyFile;
Compiler compiler = new Compiler(sourceCode, "legitidk.t", dummyFile);
compiler.doLex();
compiler.doParse();

Program program = compiler.getProgram();

// There is only a single module in this program
Module modulle = program.getModules()[0];

/* Module name must be resolution_test_1 */
assert(cmp(modulle.getName(), "resolution_test_1")==0);
TypeChecker tc = new TypeChecker(compiler);
```

We first try and search for an entity named `g` using the program as the anchoring container:

```d
// Now try to find the variable `d` by starting at the program-level
// this SHOULD fail as it should NOT be allowed
Entity var = tc.getResolver().resolveBest(program, "g");
assert(var is null);
```

This would _fail_ because any search anchored at the program-level will only be able to resolve names of the form `<moduleName>.<entity... `, hence the `assert(var is null)`.
 
After this we then try to find the variable `d` by starting at the module-level:

```d
// Try to find the variable `d` by starting at the module-level
var = tc.getResolver().resolveBest(modulle, "g");
assert(var);
assert(cast(Variable)var); // Ensure it is a variable
```

This passes, compared to the last, because the search is anchored at a non-program container and there is an entity named `"g"` within the module `modulle`.

After this we should be able to do a rooted search for a module, however, at the Program level for a module name:

```d
Entity myModule = tc.getResolver().resolveBest(program, "resolution_test_1");
assert(myModule);
assert(cast(Module)myModule); // Ensure it is a Module
```

This _passes_ because, as stated earlier, only module names and (dotted-paths starting with them) are allowed when using `resolveBest` with a program anchor container.

We then do some tests with descendancy:

```d
// The `g` should be a descendant of the module and the module of the program
assert(tc.getResolver().isDescendant(cast(Container)myModule, var));
assert(tc.getResolver().isDescendant(cast(Container)program, myModule));
```

We can also do a full path resolution including a _dotterd-path_, as we alluded to earlier. In this case we resolve using the program as the anchoring container and request resolution for the name `"resolution_test_1.g"`:

```d
// Lookup `resolution_test_1.g` but anchored from the `Program`
Entity varAgain = tc.getResolver().resolveBest(program, "resolution_test_1.g");
assert(varAgain);
assert(cast(Variable)varAgain); // Ensure it is a Variable
```

---

The last few are just related to doing name generation, similarly though, with differing anchoring points and methods:

```d
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
```