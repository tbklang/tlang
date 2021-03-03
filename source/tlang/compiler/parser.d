module compiler.parser;

import gogga;
import std.conv : to;

public final class Parser
{
    /**
    * All allowed symbols
    */
    private enum Symbol
    {
        LE_SYMBOL
    }

    /**
    * Tokens management
    */
    private string[] tokens;
    private string currentToken;
    private ulong tokenPtr;

    public static Symbol getSymbolType(string token)
    {
        /* TODO: Get symbol type of token */
        return Symbol.LE_SYMBOL;
    }

    public static void expect(Symbol symbol, string token)
    {
        /* TODO: Do checking here to see if token is a type of given symbol */
        bool isFine;
        Symbol actualType;

        /* TODO: Crash program if not */
        if(!isFine)
        {
            gprintln("Expected symbol of type "~to!(string)(symbol)~" but got "~to!(string)(actualType)~" with "~token);
        }
    }

    this(string[] tokens)
    {
        this.tokens = tokens;
        currentToken = tokens[0];
    }

    public void parse()
    {
        /* TODO: Do parsing here */
    }
}