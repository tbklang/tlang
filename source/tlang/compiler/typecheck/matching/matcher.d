module tlang.compiler.typecheck.matching.matcher;

import niknaks.functional : Optional;
import tlang.compiler.typecheck.matching.types;

// TODO: Add method here that takes in an interface and then scans
// ... for classes that implement it via matching the method's type
// ... signatures

import tlang.compiler.symbols.containers : Clazz, Interfaze;

import tlang.misc.logging;
import std.string : format;

// TODO: For loop prevention have a local variable here for visitation
private bool[Interfaze] _visited;

public Optional!(Clazz[]) findImplementations(TypeChecker tc, Interfaze i)
{
    // create entry with default `false`
    // if it doesn't exist yet
    if(i !in _visited)
    {
        _visited[i] = false;
    }

    // if already visited
    if(_visited[i])
    {
        // FIXME: place error here
        ERROR(format("Cyclic interface dependency found. Interface '%s' has aready been visited.", i));
        assert(false);
    }

    _visited[i] = true;

    // check first for super-interfaces and process those
    // first; bottom of type-tree last
    string[] superIs = i.superInterfaces();
    if(superIs.length)
    {
        foreach(string super_i; superIs)
        {
            Type super_t = tc.getType(i, super_i);
            // TODO: Check here that `super_t` refers to an interface type and throw error if not
            Interfaze super_t_i = cast(Interfaze)super_t;


            findImplementations(tc, super_t_i);
        }

    }

    // i.
    return Optional!(Clazz[]).empty();
}

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.data : Function;
import tlang.compiler.symbols.typing.core : Type;
public TypeSignature fromFunction(TypeChecker tc, Function f)
{
    Type[] tl;
    import tlang.compiler.symbols.data : VariableParameter;
    foreach(VariableParameter vp; f.getParams())
    {
        Type vp_t = tc.getType(f, vp.getType());
        tl ~= vp_t;
    }
    return TypeSignature(tl);
}

unittest
{
    
}