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

We may as well jump right into the API because it is, for the most part, relatively simple