/**
 * Type definitions for the C-based
 * code emitter
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.emit.dgen_types;

import tlang.compiler.codegen.emit.types : CodeEmitterException;
import std.string : format;
import tlang.misc.messaging : makeMessage;

/** 
 * An error that occurs during the
 * code emitting via `DGen`
 */
public final class DGenException : CodeEmitterException
{
    this(string m)
    {
        super("c generator", m);
    }

    this(T...)(string msg, T items)
    {
        this(makeMessage(msg, items));
    }
}