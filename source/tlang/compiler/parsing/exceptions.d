module compiler.parsing.exceptions;

public class ParserException : TError
{
    private Parser parser;

    this(Parser parser)
    {
        this.parser = parser;
    }

    
}

public final class SyntaxError : ParserException
{
    private SymbolType expected;
    private SymbolType provided;

    this(Parser parser, SymbolType expected, SymbolType provided)
    {
        super(parser);
        this.expected = expected;
        this.provided = provided;
    }
}