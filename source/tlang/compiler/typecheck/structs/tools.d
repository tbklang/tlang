module tlang.compiler.typecheck.structs.tools;

import tlang.compiler.symbols.data : Struct, TypedEntity, Entity;
import tlang.compiler.symbols.containers : Module;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.typecheck.exceptions : TypeCheckerException;
import tlang.compiler.typecheck.resolution : Resolver;

import tlang.misc.logging;
import tlang.misc.utils : panic;

import std.string : format;


private Struct[] getAllStructTypedChildren(TypeChecker tc, Struct st)
{
    Resolver resolver = tc.getResolver();
    Struct[] ss;

    // Obtain all members of this struct
    // which have struct types
    Entity[] structTyped_m;
    bool allStructTypedMembers(Entity e_in)
    {
        TypedEntity te = cast(TypedEntity)e_in;
        return te ? tc.isStructType(tc.getType(te.parentOf(), te.getType())) : false;
    }
    resolver.resolveWithin(st, &allStructTypedMembers, structTyped_m);

    // Make this svn depend on all
    // those struct types
    
    foreach(TypedEntity st_m; cast(TypedEntity[])structTyped_m)
    {
        Struct st_type = cast(Struct)tc.getType(st_m.parentOf(), st_m.getType());
        ss ~= st_type;    
    }

    return ss;
}

import niknaks.containers : VisitationTree;

private class NumberedTree(T) : VisitationTree!(T)
{
    private size_t n;

    this(T v)
    {
        super(v);
    }

    @property
    public void number(size_t n)
    {
        this.n = n;
    }

    @property
    public size_t number()
    {
        return this.n;
    }

    public override string toString()
    {
        return format("%s (%d)", super.toString(), this.n);
    }
}

private Struct[] getAllStructTypesDeclared(TypeChecker tc, Module mod)
{
    Resolver resolver = tc.getResolver();

    bool allStructTypes(Entity e_in)
    {
        return cast(Struct)e_in !is null;
    }

    Entity[] foundStructs;
    resolver.resolveWithin(mod, &allStructTypes, foundStructs);

    return cast(Struct[])foundStructs;
}

// TODO: Move this INTO DGen
public Struct[] getStructsInUsageOrder(TypeChecker tc, Module mod)
{
    import niknaks.containers : VisitationTree, Graph, Pool;
    import niknaks.functional : Optional;

    alias TreeType = NumberedTree!(Struct);

    // Pool of tree nodes
    Pool!(TreeType, Struct) p;

    // Dependency tree with visitation marking
    TreeType vtree = new TreeType(null);
    

    TreeType kek(Struct s)
    {
        auto s_node = p.pool(s);
        if(s_node.isVisited())
        {
            return s_node;
        }
        s_node.mark(); // Mark as visited

        foreach(Struct m_s; getAllStructTypedChildren(tc, s))
        {
            auto m_s_node = p.pool(m_s); // Pool

            // If not yet visited, then process
            // and append
            if(!m_s_node.isVisited())
            {
                kek(m_s);
                s_node.appendNode(m_s_node);
            }
        }

        return s_node;
    }

    size_t getRating(Struct s)
    {
        return getAllStructTypedChildren(tc, s).length;
    }

    foreach(Struct s; getAllStructTypesDeclared(tc, mod))
    {
        DEBUG("s:", s);
        auto s_node = p.pool(s); // pool
        DEBUG("s_node:", s_node);

        // If not visited then process and
        // append
        if(!s_node.isVisited())
        {
            kek(s);
            vtree.appendNode(s_node);
        }

        s_node.number = getRating(s); // attach rating
    }

    // Apply linearization
    Struct[] ordered = vtree.dfs();
    DEBUG("ordered:", ordered);
    assert(ordered[$-1] is null);
    ordered = ordered[0..$-1];

    return ordered;
}

// TODO: I have a niknaks datatype for this which I could use
// for this. I hate having to reoeat myself
private class StructVisitNode
{
    private Struct st;
    private bool visited;

    private StructVisitNode[] deps;
    this(Struct st)
    {
        this.st = st;
    }

    public void markVisited()
    {
        assert(!this.visited);
        this.visited = true;
    }

    public bool isVisited()
    {
        return this.visited;
    }

    public void needs(StructVisitNode dep)
    {
        this.deps ~= dep;
    }

    public StructVisitNode[] getDeps()
    {
        return this.deps;
    }

    public override string toString()
    {
        // Note: Don't do `this.deps`, if a cycle
        // exists it will toString forever, and segfault
        // when the stack is overflowed
        return format("SVN [s: %s, v: %s, d: %s]", this.st, this.visited, this.deps.length);
    }

    public Struct getStruct()
    {
        return this.st;
    }
}

/** 
 * Checks whether or not there are any
 * cyclic struct definitions. This is
 * defined as when two or more struct
 * types have members of struct types
 * that create a cycle.
 *
 * In the case of a cycle this will halt
 * the type checking process. Otherwise
 * it returns normally.
 *
 * Params:
 *   mod = the module to check
 *   tc = the `TypeChecker` instance
 * Throws: 
 *   TypeCheckerException when a cycle
 * is detected
 */
public void checkStructTypeCycles(TypeChecker tc, Module mod)
{
    foreach(Struct s; getAllStructTypesDeclared(tc, mod))
    {
        if(hasCycles(tc, s))
        {
            throw new TypeCheckerException
            (
                tc,
                TypeCheckerException.TypecheckError.CYCLE_DETECTED,
                format
                (
                    "A cyclic member type has been found in struct %s",
                    s
                )
            );
        }
    }
}

private bool hasCycle0(TypeChecker tc, Struct pivot, Struct c, bool initial)
{
    // If initial
    if(initial)
    {
        initial = false;
    }
    // If current node is the pivot
    else if(c is pivot)
    {
        return true;
    }

    // Get all children of the 
    foreach(Struct s; getAllStructTypedChildren(tc, c))
    {
        if(hasCycle0(tc, pivot, s, false))
        {
            return true;
        }
    }

    return false;
}

public bool hasCycles(TypeChecker tc, Struct pivot)
{
    return hasCycle0(tc, pivot, pivot, true);
}