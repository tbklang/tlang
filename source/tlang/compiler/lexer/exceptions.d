module compiler.lexer.exceptions;

import misc.exceptions : TError;
import compiler.lexer.core : Lexer;
import std.conv : to;

public enum LexerError
{
    EXHAUSTED_CHARACTERS,
    OTHER
}

public final class LexerException : TError
{
    public const Lexer offendingInstance;
    public const LexerError errType;

    this(Lexer offendingInstance, LexerError errType = LexerError.OTHER, string msg = "")
    {
        string positionString = "("~to!(string)(offendingInstance.getLine())~", "~to!(string)(offendingInstance.getColumn())~")";
        super("LexerException("~to!(string)(errType)~")"~(msg.length ? ": "~msg : "")~" at "~positionString);
        this.offendingInstance = offendingInstance;
        this.errType = errType;
    }

    this(Lexer offendingInstance, string msg)
    {
        this(offendingInstance, LexerError.OTHER, msg);
    }
}