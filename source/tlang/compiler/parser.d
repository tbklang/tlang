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
        /* TODO: Throw an exception here when we try get more than we can */
        return tokens[tokenPtr];
    }

    private void parseIf()
    {
        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* Parse an expression (for the condition) */
        parseExpression();
        expect(SymbolType.RBRACE, getCurrentToken());

        /* Openening { */
        nextToken();
        expect(SymbolType.OCURLY, getCurrentToken());

        /* Parse the if' statement's body AND expect a closing curly */
        parseBody();
        expect(SymbolType.CCURLY, getCurrentToken());
        nextToken();

        gprintln("parseIf(): PARSING OF IF STTAMENT BODY DONE");
    }

    private void parseWhile()
    {
        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* Parse an expression (for the condition) */
        parseExpression();
        expect(SymbolType.RBRACE, getCurrentToken());

        /* Openening { */
        nextToken();
        expect(SymbolType.OCURLY, getCurrentToken());

        /* Parse the while' statement's body AND expect a closing curly */
        parseBody();
        expect(SymbolType.CCURLY, getCurrentToken());
        nextToken();

        gprintln("parseWhile(): PARSING OF WHILE STTAMENT BODY DONE");
    }

    

    private void parseBody()
    {
        /* TODO: Implement body parsing */
        nextToken();


        /**
        * If we were able to get a closing token, `}`, then
        * this will be set to true, else it will be false by
        * default which implies we ran out of tokens before
        * we could close te body which is an error we do throw
        */
        bool closedBeforeExit;


        while(hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            
            gprintln("parseBody(): SymbolType="~to!(string)(symbol));


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
            /* If it is a while loop */
            else if(symbol == SymbolType.WHILE)
            {
                nextToken();
                parseWhile();
            }
            /* If it is a function call */
            else if(symbol == SymbolType.IDENTIFIER)
            {
                parseFuncCall();
            }
            /* If it is closing the body `}` */
            else if(symbol == SymbolType.CCURLY)
            {
                // gprintln("Error");
                // nextToken();
                gprintln("parseBody(): Exiting body by }", DebugType.WARNING);
                
                closedBeforeExit = true;
                break;
            }
            /* Error out */
            else
            {
                gprintln("parseBody(): Unknown symbol: "~getCurrentToken().getToken(), DebugType.ERROR);
            }
        }

        /* TODO: We can sometimes run out of tokens before getting our closing brace, we should fix that here */
        if(!closedBeforeExit)
        {
            gprintln("Expected closing } but ran out of tokens", DebugType.ERROR);
            exit(0);
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
                
                /* Parse the body (and it leaves ONLY when it gets the correct symbol, no expect needed) */
                parseBody();
                nextToken();
            }
            else if(getSymbolType(getCurrentToken()) == SymbolType.COMMA)
            {
                nextToken();
            }
            else
            {
                /* TODO: Error */
                gprintln("Expecting either ) or , but got "~getCurrentToken().getToken(), DebugType.ERROR);
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
        /* If it is a string literal */
        else if(symbol == SymbolType.STRING_LITERAL)
        {
            /* Get the next token */
            nextToken();
        }
        /* TODO: Add funcCal symbol type */
        else
        {
            gprintln("parseExpression(): NO MATCH", DebugType.ERROR);
            /* TODO: Something isn't right here */
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

    private void parseFuncCall()
    {
        gprintln("parseFuncCall(): Doing function call parsing");

        nextToken();


        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* Parse an expression AND end on closing brace (expect) */
        parseExpression();
        expect(SymbolType.RBRACE, getCurrentToken());
        nextToken();

        /* Expect a semi-colon */
        expect(SymbolType.SEMICOLON, getCurrentToken());
        nextToken();

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

            gprintln("parse(): Token: "~tok.getToken());

            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();

                gprintln("parse()::woah: Current token: "~tok.getToken());
            }
            else
            {
                gprintln("parse(): Geen idee", DebugType.ERROR);
                exit(0);
            }
        }
    }
}

unittest
{
    /* TODO: Add some unit tests */
}
