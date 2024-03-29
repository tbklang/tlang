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

### Resolution API

We may as well jump right into the API because it is, for the most part, relatively simple