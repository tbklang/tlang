module compiler.parsing.exceptions;

import compiler.parsing.core;
import compiler.lexer;
import misc.exceptions;
import compiler.symbols.check;
import compiler.symbols.data;
import compiler.lexer : Token;

public class ParserException : TError
{
    private Parser parser;

    this(Parser parser)
    {
        super("");
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