module compiler.parsing.exceptions;

public class ParserException : TError
{
    this()
    {

    }
}

public final class SyntaxError : ParserException
{
    private SymbolType expected;
    private SymbolType provided;

    this(SymbolType expected, SymbolType provided)
    {
        this.expected = expected;
        this.provided = provided;
    }
}