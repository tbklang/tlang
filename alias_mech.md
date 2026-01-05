How aliases are processed
=========================

## Definition

When `parseAlias()` parses an alias declaration it creates an `AliasDeclaration` AST node
which is a kind-of `Entity`. This latter fact means that it has a name associated with it
that can be obtained via `getName()`.

What makes this different however is that the `AliasDeclaration` has an embedded expression
within, this is the alias's _expression_ that must be copy-and-pasted in wherever the alias's
name is _referenced_.

## Replacement

Rather than scanning the whole source tree and applying replacements we only do so on a 
_reference by reference_ basis. Therefore, when we encounter a `VariableExpression`
within `expressionPass(...)` during dependency generation, we then follow the normal
rules:

1. Lookup the `Entity` that the `VariableExpression` refers to
2. Check if it is:
	i. a _variable_ reference
	ii. a _function_ reference
	iii. an _alias_ reference
3. If **iii** is true then we continue and run the following below code:

Firstly we have out `Expression` stored in `exp`, we then check to see
if we are handling an _expression_ which is a `VariableExpression` with:

```{.d .numberLines}
else if(cast(VariableExpression)exp)
{
	...
```

Next up we immediately extract the name or _identifier_ being referred
to by this `VariableExpression` via `getName()` and perform the lookup
starting at the container of the `VariableExpression` itself - the logic
goes that if you are referring to the variable from the expression then
looking it up from its _usage point_ (the `VariableExpression`) would
make most sense:

```{.d .numberLines}
// Extract the variable's name
VariableExpression varExp = cast(VariableExpression)exp;
string nearestName = varExp.getName();

Container varExp_p = varExp.parentOf();

// Resolve the entity the name refers to
Entity namedEntity = tc.getResolver().resolveBest(varExp_p, nearestName);
```

Now that we have entity being referred to stored in `namedEntity`
we can begin our next check.

>What _type_ of entity is it?

We're interested in the if statement here:

```{.d .numberLines}
else if(cast(AliasDeclaration)namedEntity)
{
	...
```

Here comes the more intricate part. Pay close attention to everything
that is happening as this is a great example of the procedure that is
required for replacing an item in place (via its parent) and ensuring
that the dependency node returned is what it needs to be. We will go
through it bit-by-bit.

Firstly let's perform the normal things, obtaining our `AliasDeclaration`,
its parent `Container` and incrementing the alias's reference count (so
that we can report to the user that it is used or rather if we _didn't_
reach this code it would be reported as such):

```{.d .numberLines}
AliasDeclaration ad = cast(AliasDeclaration)namedEntity;

auto ad_parent = ad.parentOf();

/* Increment reference count */
tc.touch(ad);
```

Let's now pool the `AliasDeclaration` and then via that dependency
node check if it has been visited or not. This is important as we
use this mechanism to check whether we are referring to an alias
which **exists** in the AST tree but _before_ it has been declared:

```{.d .numberLines}
/* Pool the node */
DNode aliasDecNode = pool(ad);

/**
 * Check if the alias being referenced has been
 * visited (i.e. declared)
 *
 * If it has not then throw an error
 */
if(!aliasDecNode.isVisisted())
{
    expect("Cannot reference alias", ad, "which exists but has not been declared yet");
}
```

Now begins the replacement. It is important to note that what we
are focusing on now is replacing the AST node in its parent
container - `varExp_p`. With what do we put in its place? Well,
that is what we are first going to do. We now go ahead and clone
the alias's expression. When cloning we ensure that the parent
of `cloned` is the same as `varExp`'s - namely `varExp_p`.

```{.d .numberLines}
/**
 * Obtain the expression, perform a clone
 * and parent to `ad_parent`
 */
auto ad_expr = ad.getExpr();

auto ad_expr_cl = cast(MCloneable)ad_expr;

auto cloned = ad_expr_cl.clone(varExp_p);
```

Now that we have a cloned expression properly
re-parented we can now grab the _parent node_
`varExp_p` and ask it to replace the AST node
`varExp` (our `VariableExpression`) with our
alias expression `cloned`:

```{.d .numberLines}
/**
 * Replace `varExp` in `varExp_p`
 * with `cloned`
 */
auto varExp_p_rpl = cast(MStatementReplaceable)varExp_p;
assert(varExp_p_rpl);
varExp_p_rpl.replace(varExp, cloned);
```

Lastly, because we are after all inside of `expressionPass(...)`
we must return a `DNode`. Therefore we return a dependency
node (by setting `dnode = ...`) _of_ `cloned_as_expr` (`cloned`
casted to an `Expression`):

```{.d .numberLines}
auto cloned_as_expr = cast(Expression)cloned;
dnode = cast(ExpressionDNode)expressionPass(cloned_as_expr, context);
```

Note: Because we will be replacing a node we won't want to use the
dependency node stored in `expressionPass(...)`'s `dnode` local
variable, rather we want to create a new dependency node as we
have done above.
