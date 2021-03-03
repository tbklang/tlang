module compiler.parser;

import gogga;
import std.conv : to;
import std.string : isNumeric, cmp;
import compiler.symbols : SymbolType;
import compiler.lexer : Token;
import core.stdc.stdlib;

public final class Parser
{
    /**
    * Tokens management
    */
    private Token[] tokens;
    private Token currentToken;
    private ulong tokenPtr;

    public static bool isType(string tokenStr)
    {
        return cmp(tokenStr, "byte") == 0 || cmp(tokenStr, "ubyte") == 0
            || cmp(tokenStr, "short") == 0 || cmp(tokenStr, "ushort") == 0
            || cmp(tokenStr, "int") == 0 || cmp(tokenStr, "uint") == 0
            || cmp(tokenStr, "long") == 0 || cmp(tokenStr, "ulong") == 0
            || cmp(tokenStr, "void") == 0 ;
    }

    private static bool isAlpha(string token)
    {
        foreach (char character; token)
        {
            if ((character >= 65 && character <= 90) || (character >= 97 && character <= 122))
            {

            }
            else
            {
                return false;
            }
        }

        return true;
    }

    public static SymbolType getSymbolType(Token tokenIn)
    {
        string token = tokenIn.getToken();
        /* TODO: Get symbol type of token */

        /* Character literal check */
        if (token[0] == '\'')
        {
            /* TODO: Add escape sequnece support */

            if (token[2] == '\'')
            {
                return SymbolType.CHARACTER_LITERAL;
            }
        }
        /* String literal check */
        else if (token[0] == '\"' && token[token.length - 1] == '\"')
        {
            return SymbolType.STRING_LITERAL;
        }
        /* Number literal check */
        else if (isNumeric(token))
        {
            return SymbolType.NUMBER_LITERAL;
        }
        /* Type name (TODO: Track user-defined types) */
        else if (isType(token))
        {
            return SymbolType.TYPE;
        }
        /* Identifier check (TODO: Track vars) */
        else if (isAlpha(token))
        {
            return SymbolType.IDENTIFIER;
        }
        /* Semi-colon `;` check */
        else if (token[0] == ';')
        {
            return SymbolType.SEMICOLON;
        }
        /* Assign `=` check */
        else if (token[0] == '=')
        {
            return SymbolType.ASSIGN;
        }
        /* Left-brace check */
        else if (token[0] == '(')
        {
            return SymbolType.LBRACE;
        }
        /* Right-brace check */
        else if (token[0] == ')')
        {
            return SymbolType.RBRACE;
        }
        /* Left-curly check */
        else if (token[0] == '{')
        {
            return SymbolType.OCURLY;
        }
        /* Right-curly check */
        else if (token[0] == '}')
        {
            return SymbolType.CCURLY;
        }
        /* Comma check */
        else if (token[0] == ',')
        {
            return SymbolType.COMMA;
        }
        
        
        
        

        return SymbolType.UNKNOWN;
    }

    public static void expect(SymbolType symbol, Token token)
    {
        /* TODO: Do checking here to see if token is a type of given symbol */
        SymbolType actualType = getSymbolType(token);
        bool isFine = actualType == symbol;

        /* TODO: Crash program if not */
        if (!isFine)
        {
            gprintln("Expected symbol of type " ~ to!(string)(symbol) ~ " but got " ~ to!(
                    string)(actualType) ~ " with " ~ token.toString(), DebugType.ERROR);
            import core.stdc.stdlib;

            exit(0);
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
    private void nextToken()
    {
        tokenPtr++;
    }

    private bool hasTokens()
    {
        return tokenPtr < tokens.length;
    }

    private Token getCurrentToken()
    {
        return tokens[tokenPtr];
    }

    private void parseBody()
    {
        /* TODO: Implement body parsing */
        nextToken();

        while(hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();
            }
            else if(symbol == SymbolType.CCURLY)
            {
                // gprintln("Error");
                nextToken();
                break;
            }
        }
    }

    private void parseFuncDef()
    {
        /* TODO: Implement function parsing */
        nextToken();

        /* Count for number of parameters processed */
        ulong parameterCount;

        /* Get command-line arguments */
        while(hasTokens())
        {
            /* Expect a type */
            string type = getCurrentToken().getToken();
            expect(SymbolType.TYPE, getCurrentToken());
            nextToken();

            /* Expect an identifier */
            expect(SymbolType.IDENTIFIER, getCurrentToken());
            string identifier = getCurrentToken().getToken();
            nextToken();

            parameterCount++;

            /* Check if RBRACE/ `)` */
            if(getSymbolType(getCurrentToken()) == SymbolType.RBRACE)
            {
                nextToken();
                expect(SymbolType.OCURLY, getCurrentToken());
                
                /* Parse the body */
                parseBody();
            }
            else if(getSymbolType(getCurrentToken()) == SymbolType.COMMA)
            {
                nextToken();
            }
            else
            {
                /* TODO: Error */
                gprintln("Expecting either ) or ,", DebugType.ERROR);
                exit(0);
            }

            gprintln("ParseFuncDef: ParameterDec: (Type: "~type~", Identifier: "~identifier~")",DebugType.WARNING);
            gprintln("ParseFuncDef: Parameter count: "~to!(string)(parameterCount));
        }
    }

    private void parseExpression()
    {
        /* TODO: Implement expression parsing */

        /* For testing we are just expeting a number */
        expect(SymbolType.NUMBER_LITERAL, getCurrentToken());
        gprintln("ParseExpression: Finished", DebugType.WARNING);
    }

    private void parseTypedDeclaration()
    {
        /* TODO: Save type */
        string type = getCurrentToken().getToken();
        string identifier;


        /* Expect an identifier */
        nextToken();
        expect(SymbolType.IDENTIFIER, getCurrentToken());
        identifier = getCurrentToken().getToken();


        nextToken();
        gprintln("ParseTypedDec: DecisionBtwn FuncDef/VarDef: "~getCurrentToken().getToken());

        /* Check if it is `(` (func dec) */
        SymbolType symbolType = getSymbolType(getCurrentToken());
        gprintln("ParseTypedDec: SymbolType="~to!(string)(symbolType));
        if(symbolType == SymbolType.LBRACE)
        {
            parseFuncDef();
            
        }
        /* Check for semi-colon (var dec) */
        else if(symbolType == SymbolType.SEMICOLON)
        {
            nextToken();
            gprintln("ParseTypedDec: VariableDeclaration: (Type: "~type~", Identifier: "~identifier~")", DebugType.WARNING);
        }
        /* Check for `=` (var dec) */
        else if(symbolType == SymbolType.ASSIGN)
        {
            nextToken();

            /* Now parse an expression */
            parseExpression();

            nextToken();
            expect(SymbolType.SEMICOLON, getCurrentToken());

            nextToken();

            gprintln("ParseTypedDec: VariableDeclarationWithAssingment: (Type: "~type~", Identifier: "~identifier~")", DebugType.WARNING);
        }
        else
        {
            gprintln("Expected one of the following: (, ; or =", DebugType.ERROR);
            exit(0);
        }

        /* TODO: If we outta tokens we should not call this */
        // gprintln(getCurrentToken());
        gprintln("ParseTypedDec: Je suis fini");
    }

    /* Almost like parseBody but has more */
    public void parse()
    {
        /* TODO: Do parsing here */

        /* We can have an import or vardef or funcdef */
        while (hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();
            }
            else
            {
                // gprintln("Error");
            }
        }
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
