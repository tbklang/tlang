module tlang.compiler.parsing.exceptions;

import tlang.compiler.parsing.core;
import tlang.misc.exceptions;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.lexer.core.tokens : Token;
import std.conv : to;

public class ParserException : TError
{
    this(string message)
    {
        super("ParserException: "~message);
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

        super("Syntax error: Expected "~to!(string)(expected)~" but got "~to!(string)(provided)~", see "~providedToken.toString());
    }
}