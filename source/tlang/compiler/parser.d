module compiler.parser;

import gogga;
import std.conv : to;
import std.string : isNumeric;
import compiler.symbols : SymbolType;
import compiler.lexer : Token;

public final class Parser
{
    /**
    * Tokens management
    */
    private Token[] tokens;
    private Token currentToken;
    private ulong tokenPtr;

    public static SymbolType getSymbolType(string token)
    {
        /* TODO: Get symbol type of token */

        /* Character literal check */
        if(token[0] == '\'')
        {
            /* TODO: Add escape sequnece support */

            if(token[2] == '\'')
            {
                return SymbolType.CHARACTER_LITERAL;
            }
        }
        /* String literal check */
        else if(token[0] == '\"' && token[token.length-1] == '\"')
        {
            return SymbolType.STRING_LITERAL;
        }
        /* Number literal check */
        else if(isNumeric(token))
        {
            return SymbolType.NUMBER_LITERAL;
        }

        return SymbolType.UNKNOWN;
    }

    public static void expect(SymbolType symbol, string token)
    {
        /* TODO: Do checking here to see if token is a type of given symbol */
        bool isFine;
        SymbolType actualType = getSymbolType(token);

        /* TODO: Crash program if not */
        if(!isFine)
        {
            gprintln("Expected symbol of type "~to!(string)(symbol)~" but got "~to!(string)(actualType)~" with "~token);
        }
    }

    this(Token[] tokens)
    {
        this.tokens = tokens;
        currentToken = tokens[0];
    }

    /**
    * Moves the token pointer to the next token
    *
    * Returns true if successful, false otherwise
    * (if we have exhausted the tokens source)
    */
    private bool nextToken()
    {
        if(tokenPtr < tokens.length)
        {
            tokenPtr++;
            return true;
        }
        else
        {
            return false;
        }
    }

    private Token getCurrentToken()
    {
        return currentToken;
    }

    public void parse()
    {
        /* TODO: Do parsing here */
    }
}

/* Test: Character literal */
unittest
{
    SymbolType symbol = Parser.getSymbolType("'c'");
    assert(symbol == SymbolType.CHARACTER_LITERAL);
}

/* Test: String literals */
unittest
{
    SymbolType symbol = Parser.getSymbolType("\"hello\"");
    assert(symbol == SymbolType.STRING_LITERAL);
}

/* Test: Number literals */
unittest
{
    SymbolType symbol = Parser.getSymbolType("2121");
    assert(symbol == SymbolType.NUMBER_LITERAL);
    
    symbol = Parser.getSymbolType("2121a");
    assert(symbol != SymbolType.NUMBER_LITERAL);
}



