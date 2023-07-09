module tlang.compiler.lexer.core.exceptions;

import misc.exceptions : TError;
import tlang.compiler.lexer.core.lexer : LexerInterface;
import std.conv : to;

public enum LexerError
{
    EXHAUSTED_CHARACTERS,
    OTHER
}

public final class LexerException : TError
{
    public const LexerInterface offendingInstance;
    public const LexerError errType;

    this(LexerInterface offendingInstance, LexerError errType = LexerError.OTHER, string msg = "")
    {
        string positionString = "("~to!(string)(offendingInstance.getLine())~", "~to!(string)(offendingInstance.getColumn())~")";
        super("LexerException("~to!(string)(errType)~")"~(msg.length ? ": "~msg : "")~" at "~positionString);
        this.offendingInstance = offendingInstance;
        this.errType = errType;
    }

    this(LexerInterface offendingInstance, string msg)
    {
        this(offendingInstance, LexerError.OTHER, msg);
    }
}