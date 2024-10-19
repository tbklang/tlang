module tlang.compiler.typecheck.tools.structs;

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

import niknaks.containers : VisitationTree, Pool;
import niknaks.functional : Optional;

// TODO: Move this INTO DGen
public Struct[] getStructsInUsageOrder(TypeChecker tc, Module mod)
{
    alias TreeType = VisitationTree!(Struct);

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
    }

    // Apply linearization
    Struct[] ordered = vtree.dfs();
    DEBUG("ordered:", ordered);
    assert(ordered[$-1] is null);
    ordered = ordered[0..$-1];

    return ordered;
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

/** 
 * Detects if there are cycles
 *
 * This method is to be called from `hasCycles(TypeChecker, Struct)`
 * Params:
 *   tc = the `TypeChecker` instance
 *   pivot = the pivot to compare against
 *   c = the current item being compared
 *   initial = when this is set to `true` it will not check
 * the `pivot` against itself, `c`, which occurs on the first
 * call to this. Afterwards it is set to `false` and the nested
 * calls are done with that `false` value, meaning a proper
 * pivot check can then occur. It gets rid of false pocitives
 * that occur on entry.
 * Returns: `true` if starting at `pivot` somehow lands us
 * back at `pivot` (i.e. a cycle exists)
 */
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
        if(hasCycle0(tc, pivot, s, initial))
        {
            return true;
        }
    }

    return false;
}

/** 
 * Checks if a cycle occurs in the given
 * struct type pivot. The pivot is defined
 * as the struct which, if we come across
 * it again, a loop has been detected
 *
 * Params:
 *   tc = the `TypeChecker` instance
 *   pivot = the struct to check against
 * Returns: `true` if a cycle exists,
 * `false` otherwise
 */
private bool hasCycles(TypeChecker tc, Struct pivot)
{
    return hasCycle0(tc, pivot, pivot, true);
}