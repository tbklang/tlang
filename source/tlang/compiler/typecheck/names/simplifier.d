module tlang.compiler.typecheck.names.simplifier;

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.typecheck.resolution;
import tlang.compiler.symbols.containers : Container, Module;
import std.string : strip, split;

import tlang.misc.logging;

// TODO: Move into DGen as this is only really specific to
// the C-based emitter
public bool simplify(TypeChecker tc, Container c, string s_in, ref string s_out)
{
    Resolver r = tc.getResolver();
    DEBUG("s_in:", s_in);
    s_in = strip(s_in); // strip whitespace of any kind; leading and trailing (TODO: Likewise below)

    // empty strings not valid (TODO: Woudl this ever be used as such? As in it would never be parsed anyways)
    if(!s_in.length)
    {
        return false; 
    }
    
    string[] segments = s_in.split(".");
    DEBUG("segments:", segments);

    // single element -> leave untouched
    if(segments.length == 1)
    {
        // leave untouched
        return true;
    }
    else
    {
        string f_seg = segments[0];
        Module modRef;
        
        // is the `f_seg` a module name?
        foreach(Module mod; tc.getProgram().getModules())
        {
            if(mod.getName() == f_seg)
            {
                modRef = mod;
                break;
            }
        }

        // resolve rest of path relative to this,
        // if it is fine then return the path
        // without the `f_seq`, i.e. `segments[1..$]`
        if(modRef)
        {
            // if `segments[1]` not contained in `f_seg`,
            // then error
            if(!r.resolveWithin(modRef, segments[1]))
            {
                ERROR
                (
                    "Second segment '",
                    segments[1],
                    "' does not exist in module '",
                    modRef,
                    "'"
                );
                return false;
            }

            segments = segments[1..$];
            DEBUG("Chipped off path to:", segments);
        }
    }

    s_out = "foook";


    return true;
}