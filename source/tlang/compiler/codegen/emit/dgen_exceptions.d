module tlang.compiler.codegen.emit.dgen_exceptions;

import tlang.compiler.codegen.emit.core : CodeEmitError;
import std.string : format;
import std.conv : to;
import tlang.compiler.symbols.typing.enums : Enum;

/** 
 * The C emitter error
 * type
 */
public enum ErrorType
{
    /** 
     * If an attempt to emit an enum type
     * with no members was made
     */
    EMPTY_ENUM
}

/** 
 * An exception caused by
 * the C emitter
 */
public final class DGenError : CodeEmitError
{
    /** 
     * Constructs a new error
     *
     * Params:
     *   e = the `ErrorType`
     *   m = the message
     */
    private this(ErrorType e, string m)
    {
        super
        (
            format
            (
                "DGenError (%s): %s",
                e,
                m
            )
        );
    } 
}

/** 
 * Constructs an error for
 * when an empty `Enum` is
 * provided (seeing as these
 * cannot be emitted by the
 * C emitter)
 *
 * Params:
 *   e = the offending `Enum`
 */
public static auto noEnumMembers(Enum e)
{
    return new DGenError
    (
        ErrorType.EMPTY_ENUM,
        format
        (
            "Enum '%s' has no enum members, this is unsupported by the C emitter", e.getName()
        )
    );
}