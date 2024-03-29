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

### Resolution API

Now that we have a good idea of the types involved we can take a look at the API which the resolver has to offer and how it may be used in order to perform the resolution of _entities_.

Let's first take a look at the constructor that the `Resolver` has:

```d
this
(
    Program program,
    TypeChecker typeChecker
)
```

This constructs a new resolver with the given root program and the type checking instance. This implies you must have performed parsing, constructed a `TypeChecker` and **only then** could you instantiate a resolver.

Now that we know how to construct a resolver, let's see what methods it makes available to every component from the `TypeChecker` (as it is constructed here) and onwards:

| Method                    | Return type | Description                           |
|---------------------------|-------------|---------------------------------------|
| `isDescendant(Container, Entity)` | `bool` | Returns `true` entity `e` is `c` or is within  (contained under `c`), `false` otherwise |
| `generateName0(Container, Entity)` | `string[]` | Generates the components of the path from a given entity up to (and including) the given container. The latter implies that the given `Container` must also be a kind-of `Entity` such that a name can be generated from it. |
| `generateNameBest(Entity)`| `string`    | Generate the absolute full path of the given entity without specifying which anchor point to use. |
| `generateName(Container, Entity)` | `string` |  Given an entity and a container this will generate the entity's full path relative to the given container. If the container is a `Program` then the absolute name of the entity is derived. |

### How `isDescendant(Container, Entity)` works

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