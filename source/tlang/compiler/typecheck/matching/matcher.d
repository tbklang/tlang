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

public bool doesImplement(TypeChecker tc, Clazz cl, Interfaze i)
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


            doesImplement(tc, cl, super_t_i);
        }

    }

    // obtain all type sigantures of all functions in
    // the interface
    TypeSignature[] i_tss;
    foreach(Statement s; i.getStatements())
    {
        Function f = cast(Function)s;
        TypeSignature ts = fromFunction(tc, f);
        i_tss ~= ts;
    }

    // obtain all class's type sigantures of its
    // methods (TODO: How will `this` work?, probably
    // parse-time it should have `this` formal
    // parameter inserted as the first argument?)
    TypeSignature[] c_tss;
    foreach(Statement s; cl.getStatements())
    {
        Function f = cast(Function)s;
        if(f) // TODO: Filter to only non-static functions
        {
            TypeSignature ts = fromFunction(tc, f);
            c_tss ~= ts;
        }
    }

    return false;
}

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.data : Function, Statement;
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
    return TypeSignature(tc, f.getName(), tl);
}

unittest
{
    // TypeChecker tc = new TypeChecker()
}