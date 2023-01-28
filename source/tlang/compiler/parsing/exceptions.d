module compiler.parsing.exceptions;

import compiler.parsing.core;
import misc.exceptions;
import compiler.symbols.check;
import compiler.symbols.data;
import compiler.lexer.core : Token;
import std.conv : to;

public class ParserException : TError
{
    private Parser parser;

    this(Parser parser, string message)
    {
        super(message);
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

        super(parser, "Syntax error: Expected "~to!(string)(expected)~" but got "~to!(string)(provided)~", see "~providedToken.toString());
    }
}