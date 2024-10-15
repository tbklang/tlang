module tlang.compiler.typecheck.structs.tools;

import tlang.compiler.symbols.data : Struct, TypedEntity, Entity;
import tlang.compiler.symbols.containers : Module;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.typecheck.exceptions : TypeCheckerException;
import tlang.compiler.typecheck.resolution : Resolver;

import tlang.misc.logging;

import std.string : format;

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
    Resolver resolver = tc.getResolver();

    bool allStructTypes(Entity e_in)
    {
        return cast(Struct)e_in !is null;
    }

    Entity[] foundStructs;
    resolver.resolveWithin(mod, &allStructTypes, foundStructs);

    StructVisitNode[Struct] _p;
    StructVisitNode pool(Struct st)
    {
        if(st !in _p)
        {
            _p[st] = new StructVisitNode(st);
        }
        return _p[st];
    }

    int[Struct] visitation;


    StructVisitNode proc(Struct st)
    {        
        StructVisitNode svn = pool(st);
        DEBUG("Proc pooled SVN: ", svn);
        
        if(svn.isVisited())
        {
            return svn;
        }
        svn.markVisited();

        // Obtain all members of this struct
        // which have struct types
        Entity[] structTyped_m;
        bool allStructTypedMembers(Entity e_in)
        {
            TypedEntity te = cast(TypedEntity)e_in;
            return te ? tc.isStructType(tc.getType(te.parentOf(), te.getType())) : false;
        }
        resolver.resolveWithin(st, &allStructTypedMembers, structTyped_m);
        DEBUG("structTyped_m: ", structTyped_m);
        
        // Make this svn depend on all
        // those struct types
        foreach(TypedEntity st_m; cast(TypedEntity[])structTyped_m)
        {
            Struct st_type = cast(Struct)tc.getType(st_m.parentOf(), st_m.getType());
            DEBUG("mashall");
            svn.needs(proc(st_type));
        }

        return svn;
    }

    StructVisitNode[] total;
    foreach(Struct st; cast(Struct[])foundStructs)
    {
        total ~= proc(st);
    }

    bool hasCycle(StructVisitNode start, StructVisitNode c)
    {
        foreach(StructVisitNode dep; c.getDeps())
        {
            if(dep is start)
            {
                return true;
            }
            else
            {
                return hasCycle(start, dep);
            }
        }
        return false;
    }

    foreach(StructVisitNode svn; total)
    {
        foreach(StructVisitNode dep; svn.getDeps())
        {
            if(hasCycle(svn, dep))
            {
                throw new TypeCheckerException
                (
                    tc,
                    TypeCheckerException.TypecheckError.CYCLE_DETECTED,
                    format
                    (
                        "A cyclic member type has been found in struct %s",
                        svn.getStruct()
                    )
                );
            }
        }
    }
}