/**
 * Type signature checking and matching tools
 *
 * Includes such routines for checking if
 * a given class implements a provided interface
 */
module tlang.compiler.typecheck.matching.matcher;

import niknaks.functional : Optional;
import tlang.compiler.typecheck.matching.types;
import tlang.compiler.symbols.containers : Clazz, Interfaze;
import tlang.misc.logging;
import std.string : format;
import niknaks.functional : Result, ok, error;

/** 
 * Checks if the given class implements the
 * provided interface
 *
 * Params:
 *   tc = the `TypeChecker` instance
 *   cl = the `Clazz` to check
 *   i = the `Interfaze` to test against
 * Returns: a `Result` with an okay value
 * in the auccessful case, else a `Result`
 * with an error value containing the
 * error message as a `string`
 */
public Result!(bool, string) doesImplement(TypeChecker tc, Clazz cl, Interfaze i)
{
    bool[Interfaze] _visited;

    return doesImplement0(tc, cl, i, _visited);
}

private Result!(bool, string) doesImplement0(TypeChecker tc, Clazz cl, Interfaze i, ref bool[Interfaze] _visited)
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
        return error!(string, bool)(format("Cyclic interface dependency found. Interface '%s' has aready been visited.", i));
    }

    _visited[i] = true;

    // check first for super-interfaces and process those
    // first; bottom of type-tree last
    string[] superIs = i.superInterfaces();
    if(superIs.length)
    {
        foreach(string super_i; superIs)
        {
            // TODO: Do we validate interface inherited names here? Late-checking is good :)

            Type super_t = tc.getType(i, super_i);
            // TODO: Check here that `super_t` refers to an interface type and throw error if not
            Interfaze super_t_i = cast(Interfaze)super_t;


            if(!doesImplement0(tc, cl, super_t_i, _visited))
            {
                return error!(string, bool)
                (
                    format
                    (
                        "%s does not implement interface '%s' which is a sub-interface of '%s'",
                        cl.getName(),
                        super_t.getName(),
                        i.getName()
                    )
                );
            }
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

    // now compare each by name basically
    for(size_t i_idx = 0; i_idx < i_tss.length; i_idx++)
    {
        auto i_ts = i_tss[i_idx];

        
        TypeSignature c_ts;
        bool found;
        c_lp: for(size_t c_idx = 0; c_idx < c_tss.length; c_idx++)
        {
            c_ts = c_tss[c_idx];

            if(i_ts.name() == c_ts.name())
            {
                found = true;
                break c_lp;
            }
        }

        if(!found)
        {
            return error!(string, bool)(format("No matching type signatures found for '%s'", i_ts));
        }

        Result!(bool, string) cmp_res = i_ts.cmp(c_ts);
        if(cmp_res.is_error()) // TODO: Call cmp on the TypeSignature here and pop out its Result
        {
            return cmp_res;
        }
    }

    return ok!(bool, string)(true);
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
    Type retType = tc.getType(f, f.getType());
    assert(retType);
    DEBUG("No (rettype): ", retType);
    return TypeSignature(tc, f.getName(), retType, tl);
}

version(unittest)
{
    import tlang.compiler.symbols.typing.core : Type;
    import tlang.compiler.symbols.typing.builtins : getBuiltInType;
    import tlang.compiler.typecheck.core : TypeChecker;
    import tlang.compiler.core;
    import std.stdio : File;

    import tlang.compiler.symbols.containers : Module, Clazz;
    import tlang.compiler.symbols.data : Program, Function, VariableParameter;
}

unittest
{
    string sourceFile = "source/tlang/testing/empty.t";
    
    Compiler compiler = new Compiler(gibFileData(sourceFile), sourceFile, File.tmpfile());
    TypeChecker tc = new TypeChecker(compiler);
    compiler.doLex();
    compiler.doParse();

    Program p = tc.getProgram();
    Module m = p.getModules()[0];

    // create an interface with one method
    Interfaze i_par = new Interfaze("mathable");
    VariableParameter[] par_f_vp = [new VariableParameter("ubyte", "input")];
    Function f_ident = new Function("ident", "ubyte", [], par_f_vp);
    par_f_vp[0].parentTo(f_ident);
    f_ident.parentTo(i_par);
    i_par.addStatement(f_ident);


    // create an interface with one method and which
    // is sub-interfaced by the previous interface
    Interfaze i = new Interfaze("addable");
    VariableParameter[] f_vp = [new VariableParameter("ubyte", "a"), new VariableParameter("ubyte", "b")];
    Function f_add = new Function("+", "ubyte", [], f_vp);
    f_vp[0].parentTo(f_add);
    f_vp[1].parentTo(f_add);
    f_add.parentTo(i);
    i.addStatement(f_add);
    i.addSuperInterface(i_par.getName());
    
    // create a class and add a function implementation
    Clazz cl = new Clazz("myImpl");

    VariableParameter[] cl_f_vp = [new VariableParameter("ubyte", "a"), new VariableParameter("ubyte", "b")];
    Function f_add_impl = new Function("+", "ubyte", [], cl_f_vp);
    cl_f_vp[0].parentTo(f_add_impl);
    cl_f_vp[1].parentTo(f_add_impl);
    f_add_impl.parentTo(cl);
    cl.addStatement(f_add_impl);


    // parent all to module
    i_par.parentTo(m);
    i.parentTo(m);
    cl.parentTo(m);

    // add all to module
    m.addStatements([i_par, i, cl]);


    // currently `myImpl` doesn't implement `addable` entirely
    // yet as it (`addable`) inherits from `mathable` which has
    // a single `ubyte`-returning and `ubyte`-consuming function
    // in its interface spec.
    //
    // This test should therefore fail
    assert(doesImplement(tc, cl, i).is_error());

    // We now update `myImpl` and add the previously
    // discussed function as defined in the `mathable`
    // interface
    //
    // This test should therefore pass
    VariableParameter[] cl_f_ident_vp = [new VariableParameter("ubyte", "a")];
    Function cl_f_ident = new Function("ident", "ubyte", [], cl_f_ident_vp);
    cl_f_ident_vp[0].parentTo(cl_f_ident);
    cl.addStatement(cl_f_ident);
    assert(doesImplement(tc, cl, i).is_okay());
}