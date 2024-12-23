/**
 * Type definitions for the C-based
 * code emitter
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.emit.dgen_types;

import tlang.compiler.codegen.emit.types : CodeEmitterException;
import std.string : format;

/** 
 * An error that occurs during the
 * code emitting via `DGen`
 */
public final class DGenException : CodeEmitterException
{
    this(string m)
    {
        super(format("DGen: %s", m));
    }

    this(T...)(string msg, T items)
    {
        this(format(msg, items));
    }
}