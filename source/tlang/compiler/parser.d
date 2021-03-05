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

    /**
    * Crashes the program if the given token is not a symbol
    * the same as the givne expected one
    */
    public static void expect(SymbolType symbol, Token token)
    {
        /* TODO: Do checking here to see if token is a type of given symbol */
        SymbolType actualType = getSymbolType(token);
        bool isFine = actualType == symbol;

        /* TODO: Crash program if not */
        if (!isFine)
        {
            expect("Expected symbol of type " ~ to!(string)(symbol) ~ " but got " ~ to!(
                    string)(actualType) ~ " with " ~ token.toString());
        }
    }

    /**
    * Crashes the parser with the given message
    */
    public static void expect(string message)
    {
        gprintln(message, DebugType.ERROR);
        exit(0); /* TODO: Exit code */  /* TODO: Version that returns or asserts for unit tests */
    }

    /**
    * Costructs a new parser with the given set of Tokens
    */
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

    /**
    * Parses if statements
    *
    * TODO: Check kanban
    */
    private void parseIf()
    {
        gprintln("parseIf(): Enter", DebugType.WARNING);

        /* Pop off the `if` */
        nextToken();

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

        gprintln("parseIf(): Leave", DebugType.WARNING);
    }

    private void parseWhile()
    {
        gprintln("parseWhile(): Enter", DebugType.WARNING);

        /* Pop off the `while` */
        nextToken();

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

        gprintln("parseWhile(): Leave", DebugType.WARNING);
    }

    private void parseBody()
    {
        gprintln("parseBody(): Enter", DebugType.WARNING);

        /* TODO: Implement body parsing */
        nextToken();

        /**
        * If we were able to get a closing token, `}`, then
        * this will be set to true, else it will be false by
        * default which implies we ran out of tokens before
        * we could close te body which is an error we do throw
        */
        bool closedBeforeExit;

        while (hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            gprintln("parseBody(): SymbolType=" ~ to!(string)(symbol));

            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();
            }
            /* If it is a branch */
            else if (symbol == SymbolType.IF)
            {
                parseIf();
            }
            /* If it is a while loop */
            else if (symbol == SymbolType.WHILE)
            {
                parseWhile();
            }
            /* If it is a function call */
            else if (symbol == SymbolType.IDENTIFIER)
            {
                parseFuncCall();
            }
            /* If it is closing the body `}` */
            else if (symbol == SymbolType.CCURLY)
            {
                // gprintln("Error");
                // nextToken();
                gprintln("parseBody(): Exiting body by }", DebugType.WARNING);

                closedBeforeExit = true;
                break;
            }
            /* If it is a class definition */
            else if (symbol == SymbolType.CLASS)
            {
                parseClass();
            }
            /* Error out */
            else
            {
                gprintln("parseBody(): Unknown symbol: " ~ getCurrentToken()
                        .getToken(), DebugType.ERROR);
            }
        }

        /* TODO: We can sometimes run out of tokens before getting our closing brace, we should fix that here */
        if (!closedBeforeExit)
        {
            expect("Expected closing } but ran out of tokens");
        }

        gprintln("parseBody(): Leave", DebugType.WARNING);
    }

    private void parseFuncDef()
    {
        gprintln("parseFuncDef(): Enter", DebugType.WARNING);

        /* TODO: Implement function parsing */
        nextToken();

        /* Count for number of parameters processed */
        ulong parameterCount;

        /* Get command-line arguments */
        while (hasTokens())
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
            if (getSymbolType(getCurrentToken()) == SymbolType.RBRACE)
            {
                nextToken();
                expect(SymbolType.OCURLY, getCurrentToken());

                /* Parse the body (and it leaves ONLY when it gets the correct symbol, no expect needed) */
                parseBody();
                nextToken();
            }
            else if (getSymbolType(getCurrentToken()) == SymbolType.COMMA)
            {
                nextToken();
            }
            else
            {
                /* TODO: Error */
                expect("Expecting either ) or , but got " ~ getCurrentToken().getToken());
            }

            gprintln("ParseFuncDef: ParameterDec: (Type: " ~ type ~ ", Identifier: " ~ identifier ~ ")",
                    DebugType.WARNING);
            gprintln("ParseFuncDef: Parameter count: " ~ to!(string)(parameterCount));
        }

        gprintln("parseFuncDef(): Leave", DebugType.WARNING);
    }

    /**
    * Parses an expression
    *
    * TODO:
    *
    * I think we need a loop here to move till we hit a terminator like `)`
    * in the case of a condition's/function's argument expression or `;` in
    * the case of a assignment's expression.
    *
    * This means we will be able to get the `+` token and process it
    * We will also terminate on `;` or `)` and that means our `else` can be
    * left to error out for unknowns then
    */
    private void parseExpression()
    {
        gprintln("parseExpression(): Enter", DebugType.WARNING);

        /* TODO: Implement expression parsing */

        SymbolType symbol = getSymbolType(getCurrentToken());

        /* If it is a number literal */
        if (symbol == SymbolType.NUMBER_LITERAL)
        {
            /* Get the next token */
            nextToken();

            /* Check if the token is a mathematical operator */
            if (isMathOp(getCurrentToken()))
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
        else if (symbol == SymbolType.STRING_LITERAL)
        {
            /* Get the next token */
            nextToken();
        }
        /* If it is an identifier */
        else if (symbol == SymbolType.IDENTIFIER)
        {
            string identifier = getCurrentToken().getToken();

            nextToken();

            /* If the symbol is `(` then function call */
            if (getSymbolType(getCurrentToken()) == SymbolType.LBRACE)
            {
                /* TODO: Implement function call parsing */
            }
            else
            {
                /* TODO: Leave the token here */
                /* TODO: Just leave it, yeah */
            }
        }
        /* TODO: Add the `)` and `;` detection here to terminate ourselves */
        else
        {
            gprintln("parseExpression(): NO MATCH", DebugType.ERROR);
            /* TODO: Something isn't right here */
        }

        gprintln("parseExpression(): Leave", DebugType.WARNING);
    }

    private void parseTypedDeclaration()
    {
        gprintln("parseTypedDeclaration(): Enter", DebugType.WARNING);

        /* TODO: Save type */
        string type = getCurrentToken().getToken();
        string identifier;

        /* Expect an identifier */
        nextToken();
        expect(SymbolType.IDENTIFIER, getCurrentToken());
        identifier = getCurrentToken().getToken();

        nextToken();
        gprintln("ParseTypedDec: DecisionBtwn FuncDef/VarDef: " ~ getCurrentToken().getToken());

        /* Check if it is `(` (func dec) */
        SymbolType symbolType = getSymbolType(getCurrentToken());
        gprintln("ParseTypedDec: SymbolType=" ~ to!(string)(symbolType));
        if (symbolType == SymbolType.LBRACE)
        {
            parseFuncDef();

        }
        /* Check for semi-colon (var dec) */
        else if (symbolType == SymbolType.SEMICOLON)
        {
            nextToken();
            gprintln("ParseTypedDec: VariableDeclaration: (Type: " ~ type ~ ", Identifier: " ~ identifier ~ ")",
                    DebugType.WARNING);
        }
        /* Check for `=` (var dec) */
        else if (symbolType == SymbolType.ASSIGN)
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

            gprintln("ParseTypedDec: VariableDeclarationWithAssingment: (Type: "
                    ~ type ~ ", Identifier: " ~ identifier ~ ")", DebugType.WARNING);
        }
        else
        {
            expect("Expected one of the following: (, ; or =");
        }

        /* TODO: If we outta tokens we should not call this */
        // gprintln(getCurrentToken());
        gprintln("parseTypedDeclaration(): Leave", DebugType.WARNING);
    }

    /**
    * Parses a class definition
    *
    * This is called when there is an occurrence of
    * a token `class`
    */
    private void parseClass()
    {
        gprintln("parseClass(): Enter", DebugType.WARNING);

        /* Pop off the `class` */
        nextToken();

        /* Get the class's name */
        expect(SymbolType.IDENTIFIER, getCurrentToken());
        string className = getCurrentToken().getToken();
        gprintln("parseClass(): Class name found '" ~ className ~ "'");

        /* Expect a `{` */
        nextToken();
        expect(SymbolType.OCURLY, getCurrentToken());

        /* Parse a body */
        parseBody();

        /* Pop off the ending `}` */
        nextToken();

        gprintln("parseClass(): Leave", DebugType.WARNING);
    }

    private void parseStatement()
    {
        gprintln("parseStatement(): Enter", DebugType.WARNING);

        /* TODO: Implement parse statement */

        /**
        * TODO: We should remove the `;` from parseFuncCall
        * And rather do the following here:
        *
        * 1. parseFuncCall()
        * 2. expect(;)
        */

        gprintln("parseStatement(): Leave", DebugType.WARNING);
    }

    private void parseFuncCall()
    {
        gprintln("parseFuncCall(): Enter", DebugType.WARNING);

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

        gprintln("parseFuncCall(): Leave", DebugType.WARNING);
    }

    /* Almost like parseBody but has more */
    /**
    * TODO: For certain things like `parseClass` we should
    * keep track of what level we are at as we shouldn't allow
    * one to define classes within functions
    */
    /* TODO: Variables should be allowed to have letters in them and underscores */
    public void parse()
    {
        gprintln("parse(): Enter", DebugType.WARNING);

        /* TODO: Do parsing here */

        /* We can have an import or vardef or funcdef */
        while (hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            gprintln("parse(): Token: " ~ tok.getToken());

            /* If it is a type */
            if (symbol == SymbolType.TYPE)
            {
                /* Might be a function, might be a variable */
                parseTypedDeclaration();

                gprintln("parse()::woah: Current token: " ~ tok.getToken());
            }
            /* If it is a class */
            else if (symbol == SymbolType.CLASS)
            {
                parseClass();
            }
            else
            {
                expect("parse(): Unknown '" ~ tok.getToken() ~ "'");
            }
        }

        gprintln("parse(): Leave", DebugType.WARNING);
    }
}

unittest
{
    /* TODO: Add some unit tests */
}
