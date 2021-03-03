module compiler.symbols;

import compiler.lexer : Token;

/**
    * All allowed symbols
    * TODO: There should be a symbol class with sub-types
    */
public enum SymbolType
{
    LE_SYMBOL,
    IDENTIFIER,
    NUMBER_LITERAL,
    CHARACTER_LITERAL,
    STRING_LITERAL,
    UNKNOWN
}

public class Symbol
{
    /* Token */
    private Token token;
    private SymbolType symbolType;
    
    this(SymbolType symbolType, Token token)
    {
        this.token = token;
        this.symbolType = symbolType;
    }
}

/* TODO: Later build classes specific to symbol */
