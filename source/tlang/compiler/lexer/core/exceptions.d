/**
 * Exception definitions
 */
module tlang.compiler.lexer.core.exceptions;

import tlang.misc.exceptions : TError;
import tlang.compiler.lexer.core.lexer : LexerInterface;
import std.conv : to;

/** 
 * The specified error which occurred
 */
public enum LexerError
{
    /** 
     * If all the characters were
     * exhausted
     */
    EXHAUSTED_CHARACTERS, // FIXME: This seems Basiclexer specific, and should be removed (OTHER should then be used)

    /**
     * If the token cursor
     * is out of bounds
     */
    EXHAUSTED_TOKENS,

    /** 
     * Generic error
     */
    OTHER
}

/** 
 * Represents an exception that can occur
 * when using a `LexerInterface`
 */
public final class LexerException : TError
{
    /** 
     * The offending `LexerInterface` instance
     */
    public const LexerInterface offendingInstance;

    /** 
     * The sub-error type (specific error)
     */
    public const LexerError errType;

    /** 
     * Constructs a new `LexerException` with the given offending instance
     * where the error occured from and the default error type and no
     * custom message
     *
     * Params:
     *   offendingInstance = the offending `LexerInterface`
     *   errType = the sub-error type as a `LexerError`
     *   msg = the custom message (default is empty/`""`)
     */
    this(LexerInterface offendingInstance, LexerError errType = LexerError.OTHER, string msg = "")
    {
        string positionString = "("~to!(string)(offendingInstance.getLine())~", "~to!(string)(offendingInstance.getColumn())~")";
        super("LexerException("~to!(string)(errType)~")"~(msg.length ? ": "~msg : "")~" at "~positionString);
        this.offendingInstance = offendingInstance;
        this.errType = errType;
    }

    /** 
     * Constructs a new `LexerException` with the given offending instance
     * where the error occured from and the default error type and a
     * custom message
     *
     * Params:
     *   offendingInstance = the offending `LexerInterface`
     *   msg = the custom message
     */
    this(LexerInterface offendingInstance, string msg)
    {
        this(offendingInstance, LexerError.OTHER, msg);
    }
}