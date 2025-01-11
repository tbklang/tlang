module tlang.compiler.parsing.exceptions;

import tlang.compiler.parsing.core;
import tlang.misc.exceptions;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.lexer.core.tokens : Token;
import std.conv : to;

public class ParserException : TError
{
    public enum ParserErrorType
    {
        GENERAL_ERROR,
        LITERAL_OVERFLOW
    }

    this(ParserErrorType errType = ParserErrorType.GENERAL_ERROR, string message = "")
    {
        super("ParserException("~to!(string)(errType)~"): "~message);
    }
}

public final class SyntaxError : ParserException
{
    private SymbolType expected;
    private SymbolType provided;
    private Token providedToken;

    this(SymbolType expected, Token providedToken)
    {
        this.expected = expected;
        this.provided = getSymbolType(providedToken);
        this.providedToken = providedToken;

        msg = "Syntax error: Expected "~to!(string)(expected)~" but got "~to!(string)(provided)~", see "~providedToken.toString();
    }
}