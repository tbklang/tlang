module tlang.compiler.parsing.exceptions;

import tlang.compiler.parsing.core;
import tlang.misc.exceptions;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.lexer.core.tokens : Token;
import std.conv : to;
import tlang.compiler.reporting : LineInfo, report;

public class ParserException : TError
{
    private Parser parser;

    public enum ParserErrorType
    {
        GENERAL_ERROR,
        LITERAL_OVERFLOW
    }

    this(Parser parser, ParserErrorType errType = ParserErrorType.GENERAL_ERROR, string message = "")
    {
        super("ParserException("~to!(string)(errType)~"): "~message);
        this.parser = parser;
    }
}

public final class SyntaxError : ParserException
{
    private SymbolType expected;
    private SymbolType provided;
    private Token providedToken;

    this(Parser parser, SymbolType expected, Token providedToken)
    {
        this.expected = expected;
        this.provided = getSymbolType(providedToken);
        this.providedToken = providedToken;

        super(parser);

        msg = report
        (
            "Syntax error: Expected "~to!(string)(expected)~" but got "~to!(string)(provided)~", see "~providedToken.toString(),
            providedToken
        );
    }
}