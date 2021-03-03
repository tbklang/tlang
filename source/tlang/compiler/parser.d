module compiler.parser;

import gogga;
import std.conv : to;
import std.string : isNumeric, cmp;
import compiler.symbols;
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

    private void parseIf()
    {
        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* Parse an expression */
        parseExpression();
        expect(SymbolType.RBRACE, getCurrentToken());

        nextToken();
        expect(SymbolType.OCURLY, getCurrentToken());

        /* Parse the if' statement's body */
        parseBody();
        gprintln("PARSING OF IF STTAMENT BODY DONE");

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

            
            gprintln("parseBody: SymbolType="~to!(string)(symbol));


            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();
            }
            /* If it is a branch */
            else if(symbol == SymbolType.IF)
            {
                nextToken();
                parseIf();
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

        SymbolType symbol = getSymbolType(getCurrentToken());

        /* If it is a number literal */
        if(symbol == SymbolType.NUMBER_LITERAL)
        {
            /* Get the next token */
            nextToken();

            /* Check if the token is a mathematical operator */
            if(isMathOp(getCurrentToken()))
            {
                /* TODO:check math op */
                nextToken();

                /* Parse an expression */
                parseExpression();
            }
            else
            {
                
            }
        }
        else
        {
        
        }

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

            /**
            * The symbol that returned us from `parseExpression` must
            * be a semi-colon
            */
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

unittest
{
    /* TODO: Add some unit tests */
}
