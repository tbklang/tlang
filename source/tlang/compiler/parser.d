module compiler.parser;

import gogga;
import std.conv : to;
import std.string : isNumeric, cmp;
import compiler.symbols;
import compiler.lexer : Token;
import core.stdc.stdlib;
import misc.exceptions : TError;

// public final class ParserError : TError
// {

// }



bool isUnitTest;

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
        //throw new TError(message);
        gprintln(message, DebugType.ERROR);

        if(isUnitTest)
        {
            assert(false);
        }
        else
        {
            exit(0); /* TODO: Exit code */  /* TODO: Version that returns or asserts for unit tests */
        }
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

        while (hasTokens())
        {        
            /* This will only be called once (it is what caused a call to parseIf()) */
            if (getSymbolType(getCurrentToken()) == SymbolType.IF)
            {
                /* Pop off the `if` */
                nextToken();

                /* Expect an opening brace `(` */
                expect(SymbolType.LBRACE, getCurrentToken());
                nextToken();

                /* Parse an expression (for the condition) */
                parseExpression();
                expect(SymbolType.RBRACE, getCurrentToken());

                /* Opening { */
                nextToken();
                expect(SymbolType.OCURLY, getCurrentToken());

                /* Parse the if' statement's body AND expect a closing curly */
                parseBody();
                expect(SymbolType.CCURLY, getCurrentToken());
                nextToken();
            }
            /* If we get an else as the next symbol */
            else if (getSymbolType(getCurrentToken()) == SymbolType.ELSE)
            {
                /* Pop off the `else` */
                nextToken();

                /* Check if we have an `if` after the `{` (so an "else if" statement) */
                if (getSymbolType(getCurrentToken()) == SymbolType.IF)
                {
                    /* Pop off the `if` */
                    nextToken();

                    /* Expect an opening brace `(` */
                    expect(SymbolType.LBRACE, getCurrentToken());
                    nextToken();

                    /* Parse an expression (for the condition) */
                    parseExpression();
                    expect(SymbolType.RBRACE, getCurrentToken());

                    /* Opening { */
                    nextToken();
                    expect(SymbolType.OCURLY, getCurrentToken());

                    /* Parse the if' statement's body AND expect a closing curly */
                    parseBody();
                    expect(SymbolType.CCURLY, getCurrentToken());
                    nextToken();
                }
                /* Check for opening curly (just an "else" statement) */
                else if (getSymbolType(getCurrentToken()) == SymbolType.OCURLY)
                {
                    /* Parse the if' statement's body (starting with `{` AND expect a closing curly */
                    parseBody();
                    expect(SymbolType.CCURLY, getCurrentToken());
                    nextToken();

                    /* Exit, this is the end of the if statement as an else is reached */
                    break;
                }
                /* Error out if no `{` or `if` */
                else
                {
                    expect("Expected either if (for else if) or { for (else)");
                }
            }
            /* If we get anything else, then we are done with if statement */
            else
            {
                break;
            }
        }

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

    private void previousToken()
    {
        tokenPtr--;   
    }

    public Statement parseName()
    {
        Statement ret;

        /* Save the name or type */
        string nameTYpe = getCurrentToken().getToken();

        /* TODO: The problem here is I don't want to progress the token */

        /* Get next token */
        nextToken();
        SymbolType type = getSymbolType(getCurrentToken());

        /* If we have `(` then function call */
        if(type == SymbolType.LBRACE)
        {
            /* TODO: Collect and return */
            previousToken();
            parseFuncCall();

             /* Expect a semi-colon */
            expect(SymbolType.SEMICOLON, getCurrentToken());
            nextToken();
        }
        /* If we have an identifier/type then declaration */
        else if(type == SymbolType.IDENT_TYPE)
        {
            previousToken();
            ret = parseTypedDeclaration();
        }
        /* Any other case */
        else
        {
            expect("Error expected ( for var/func def");
        }
       



        return ret;
    }

    private Statement[] parseBody()
    {
        gprintln("parseBody(): Enter", DebugType.WARNING);

        /* TODO: Implement body parsing */
        Statement[] statements;

        /* Consume the `{` symbol */
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
            if (symbol == SymbolType.IDENT_TYPE)
            {
                
                /* Might be a function, might be a variable */
                statements ~= parseName();
            }
            /* If it is an accessor */
            else if (isAccessor(tok))
            {
                statements ~= parseAccessor();
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
            /* If it is a function call (further inspection needed) */
            else if (symbol == SymbolType.IDENT_TYPE)
            {
                /* Function calls can have dotted identifiers */
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
                /* Parse the class and add its statements */
                statements ~= parseClass();
            }
            /* Error out */
            else
            {
                expect("parseBody(): Unknown symbol: " ~ getCurrentToken()
                        .getToken());
            }
        }

        /* TODO: We can sometimes run out of tokens before getting our closing brace, we should fix that here */
        if (!closedBeforeExit)
        {
            expect("Expected closing } but ran out of tokens");
        }

        gprintln("parseBody(): Leave", DebugType.WARNING);

        return statements;
    }

    private AccessorType getAccessorType(Token token)
    {
        if(getSymbolType(token) == SymbolType.PUBLIC)
        {
            return AccessorType.PUBLIC;
        }
        else if(getSymbolType(token) == SymbolType.PROTECTED)
        {
            return AccessorType.PROTECTED;
        }
        else if(getSymbolType(token) == SymbolType.PRIVATE)
        {
            return AccessorType.PRIVATE;
        }
        else
        {
            return AccessorType.UNKNOWN;
        }
    }

    /* STATUS: Not being used yet */
    private Entity parseAccessor()
    {
        Entity entity;

        /* Save and consume the accessor */
        AccessorType accessorType = getAccessorType(getCurrentToken());
        nextToken();

        /* TODO: Only allow, private, public, protected */
        /* TODO: Pass this to call for class prsewr or whatever comes after the accessor */

        /* Get the current token's symbol type */
        SymbolType symbolType = getSymbolType(getCurrentToken());

        /* If class */
        if(symbolType == SymbolType.CLASS)
        {
            /* TODO: Set accessor on returned thing */
            entity = parseClass();
        }
        /* If typed-definition (function or variable) */
        else if(symbolType == SymbolType.IDENT_TYPE)
        {
            /* TODO: Set accesor on returned thing */
            entity = cast(Entity)parseName();

            if(!entity)
            {
                expect("Accessor got func call when expecting var/func def");
            }
        }
        /* Error out */
        else
        {
            expect("Expected either function definition, variable declaration or class definition");
        }

        entity.setAccessorType(accessorType);

        return entity;
    }

    private void parseFunctionArguments()
    {
        /* TODO: Use later */
        /* TODO: Add support for default values for function arguments */
    }

    private struct funcDefPair
    {
        Statement[] bodyStatements;
        Variable[] args;
    }

    private funcDefPair parseFuncDef()
    {
        gprintln("parseFuncDef(): Enter", DebugType.WARNING);

        Statement[] statements;
        Variable[] argumentList;
        funcDefPair bruh;
        

        /* Consume the `(` token */
        nextToken();

        /* Count for number of parameters processed */
        ulong parameterCount;

        /* Expecting more arguments */
        bool moreArgs;

        /* Get command-line arguments */
        while (hasTokens())
        {
            /* Check if the first thing is a type */
            if(getSymbolType(getCurrentToken()) == SymbolType.IDENT_TYPE)
            {
                /* Get the type (this can be doted) */
                string type = getCurrentToken().getToken();
                nextToken();

                /* Get the identifier (This CAN NOT be dotted) */
                expect(SymbolType.IDENT_TYPE, getCurrentToken());
                if(isIdentifier_Dot(getCurrentToken()))
                {
                    expect("Identifier can not be path");
                }
                string identifier = getCurrentToken().getToken();
                nextToken();


                /* Add the local variable (parameter variable) */
                argumentList ~= new Variable(type, identifier);

                moreArgs = false;

                parameterCount++;
            }
            /* If we get a comma */
            else if(getSymbolType(getCurrentToken()) == SymbolType.COMMA)
            {
                /* Consume the `,` */
                nextToken();

                moreArgs = true;
            }
            /* Check if it is a closing brace */
            else if(getSymbolType(getCurrentToken()) == SymbolType.RBRACE)
            {
                /* Make sure we were not expecting more arguments */
                if(!moreArgs)
                {
                    /* Consume the `)` */
                    nextToken();
                    break;
                }
                /* Error out if we were and we prematurely ended */
                else
                {
                    expect(SymbolType.IDENT_TYPE, getCurrentToken());
                }
            }
            /* Error out */
            else
            {
                expect("Expected either type or )");
            }
        }

        expect(SymbolType.OCURLY, getCurrentToken());

        /* Parse the body (and it leaves ONLY when it gets the correct symbol, no expect needed) */
        statements = parseBody();
        nextToken();

        gprintln("ParseFuncDef: Parameter count: " ~ to!(string)(parameterCount));
        gprintln("parseFuncDef(): Leave", DebugType.WARNING);

        bruh.bodyStatements = statements;
        bruh.args = argumentList;

        return bruh;
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
    private Expression parseExpression()
    {
        gprintln("parseExpression(): Enter", DebugType.WARNING);

        Expression expression;

        Expression[] expressions;

        /* TODO: Implement expression parsing */

        /**
        * We loop here until we hit something that closes
        * an expression, in other words an expression
        * appears in variable assignments which end with a
        * `;`, they also appear in conditions which end in
        * a `)`
        */
        while (true)
        {
            SymbolType symbol = getSymbolType(getCurrentToken());

            /* If it is a number literal */
            if (symbol == SymbolType.NUMBER_LITERAL)
            {
                /* Get the next token */
                nextToken();
            }
            /* If it is a maths operator */
            else if (isMathOp(getCurrentToken()))
            {
                /* TODO: Parse expression or pass arithemetic (I think latter) */
                nextToken();

                /* Parse expression */
                parseExpression();
            }
            /* If it is a string literal */
            else if (symbol == SymbolType.STRING_LITERAL)
            {
                /* Get the next token */
                nextToken();
            }
            /* If it is an identifier */
            else if (symbol == SymbolType.IDENT_TYPE)
            {
                string identifier = getCurrentToken().getToken();

                nextToken();

                /* If the symbol is `(` then function call */
                if (getSymbolType(getCurrentToken()) == SymbolType.LBRACE)
                {
                    /* TODO: Implement function call parsing */
                    previousToken();
                    parseFuncCall();
                }
                else
                {
                    /* TODO: Leave the token here */
                    /* TODO: Just leave it, yeah */
                    // expect("poes");
                }
            }
            /* Detect if this expression is coming to an end, then return */
            else if (symbol == SymbolType.SEMICOLON || symbol == SymbolType.RBRACE)
            {
                break;
            }
            /**
            * For ()
            */
            else if (symbol == SymbolType.LBRACE)
            {
                /* Consume the `(` */
                nextToken();

                /* Parse the inner expression till terminator */
                parseExpression();

                /* Consume the terminator */
                nextToken();
            }
            else
            {
                //gprintln("parseExpression(): NO MATCH", DebugType.ERROR);
                /* TODO: Something isn't right here */
                expect("Expected expression terminator ) or ;");
            }
        }

        gprintln("parseExpression(): Leave", DebugType.WARNING);

        expression = new Expression(expressions);

        return expression;
    }

    private TypedEntity parseTypedDeclaration()
    {
        gprintln("parseTypedDeclaration(): Enter", DebugType.WARNING);


        /* Generated object */
        TypedEntity generated;


        /* TODO: Save type */
        string type = getCurrentToken().getToken();
        string identifier;

        /* Expect an identifier (CAN NOT be dotted) */
        nextToken();
        expect(SymbolType.IDENT_TYPE, getCurrentToken());
        if(!isIdentifier_NoDot(getCurrentToken()))
        {
            expect("Identifier cannot be dotted");
        }
        identifier = getCurrentToken().getToken();

        nextToken();
        gprintln("ParseTypedDec: DecisionBtwn FuncDef/VarDef: " ~ getCurrentToken().getToken());

        /* Check if it is `(` (func dec) */
        SymbolType symbolType = getSymbolType(getCurrentToken());
        gprintln("ParseTypedDec: SymbolType=" ~ to!(string)(symbolType));
        if (symbolType == SymbolType.LBRACE)
        {
            funcDefPair pair = parseFuncDef();

            generated = new Function(identifier, type, pair.bodyStatements, pair.args);
            
            import std.stdio;
            writeln(to!(string)((cast(Function)generated).getVariables()));
        }
        /* Check for semi-colon (var dec) */
        else if (symbolType == SymbolType.SEMICOLON)
        {
            nextToken();
            gprintln("ParseTypedDec: VariableDeclaration: (Type: " ~ type ~ ", Identifier: " ~ identifier ~ ")",
                    DebugType.WARNING);

            generated = new Variable(type, identifier);
        }
        /* Check for `=` (var dec) */
        else if (symbolType == SymbolType.ASSIGN)
        {
            nextToken();

            /* Now parse an expression */
            Expression expression = parseExpression();

            VariableAssignment varAssign = new VariableAssignment(expression);

            /**
            * The symbol that returned us from `parseExpression` must
            * be a semi-colon
            */
            expect(SymbolType.SEMICOLON, getCurrentToken());

            nextToken();

            gprintln("ParseTypedDec: VariableDeclarationWithAssingment: (Type: "
                    ~ type ~ ", Identifier: " ~ identifier ~ ")", DebugType.WARNING);
            
            Variable variable = new Variable(type, identifier);
            variable.addAssignment(varAssign);

            generated = variable;
        }
        else
        {
            expect("Expected one of the following: (, ; or =");
        }

        /* TODO: If we outta tokens we should not call this */
        // gprintln(getCurrentToken());
        gprintln("parseTypedDeclaration(): Leave", DebugType.WARNING);

        return generated;
    }

    /**
    * Parses a class definition
    *
    * This is called when there is an occurrence of
    * a token `class`
    */
    private Clazz parseClass()
    {
        gprintln("parseClass(): Enter", DebugType.WARNING);

        Clazz generated;

        /* Pop off the `class` */
        nextToken();

        /* Get the class's name (CAN NOT be dotted) */
        expect(SymbolType.IDENT_TYPE, getCurrentToken());
        expect(to!(string)(isIdentifier_Dot(getCurrentToken())));
        if(isIdentifier_Dot(getCurrentToken()))
        {
            expect("Class name in declaration cannot be path");
        }
        string className = getCurrentToken().getToken();
        gprintln("parseClass(): Class name found '" ~ className ~ "'");
        nextToken();

        generated = new Clazz(className);


        /* TODO: If we have the inherit symbol `:` */
        if(getSymbolType(getCurrentToken()) == SymbolType.INHERIT_OPP)
        {
            /* TODO: Loop until `}` */

            /* Consume the inheritance operator `:` */
            nextToken();

            while(true)
            {
                /* Check if it is an identifier (may be dotted) */
                expect(SymbolType.IDENT_TYPE, getCurrentToken());
                nextToken();

                /* Check if we have ended with a `{` */
                if(getSymbolType(getCurrentToken()) == SymbolType.OCURLY)
                {
                    /* Exit */
                    break;
                }
                /* If we get a comma */
                else if(getSymbolType(getCurrentToken()) == SymbolType.COMMA)
                {
                    /* Consume */
                    nextToken();
                }
                /* Error out if we get anything else */
                else
                {
                    expect("Expected either { or ,");
                }
            }
        }

        /* TODO: Technically we should be more specific, this does too much */
        /* Parse a body */
        Statement[] statements = parseBody();
        generated.addStatements(statements);

        /* Pop off the ending `}` */
        nextToken();

        gprintln("parseClass(): Leave", DebugType.WARNING);

        return generated;
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

        /* TODO: Save name */

        nextToken();

        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* TODO: SHould be allowing , seperated arguments */
        /* Parse an expression AND end on closing brace (expect) */
        parseExpression();
        expect(SymbolType.RBRACE, getCurrentToken());
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
    public Program parse()
    {
        gprintln("parse(): Enter", DebugType.WARNING);

        Program program;

        /* TODO: Do parsing here */

        /* Expect `module` and module name and consume them (and `;`) */
        expect(SymbolType.MODULE, getCurrentToken());
        nextToken();

        /* Module name may NOT be dotted (TODO: Maybe it should be yeah) */
        expect(SymbolType.IDENT_TYPE, getCurrentToken());
        string programName = getCurrentToken().getToken();
        nextToken();

        expect(SymbolType.SEMICOLON, getCurrentToken());
        nextToken();

        /* Initialize Program */
        program = new Program(programName);

        /* TODO: do `hasTokens()` check */
        /* TODO: We should add `hasTokens()` to the `nextToken()` */
        /* TODO: And too the `getCurrentTokem()` and throw an error when we have ran out rather */

        /* We can have an import or vardef or funcdef */
        while (hasTokens())
        {
            /* Get the token */
            Token tok = getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            gprintln("parse(): Token: " ~ tok.getToken());

            /* If it is a type */
            if (symbol == SymbolType.IDENT_TYPE)
            {
                /* Might be a function, might be a variable */
                TypedEntity varFunc = cast(TypedEntity)parseName();

                /* If cast fails then it was a funcall */
                if(!varFunc)
                {
                    /* FUnction calls not allowed in top level body */
                    expect("Expected var/func def got funcall");
                }

                /* Add this statement to the program's statement list */
                program.addStatement(varFunc);
            }
            /* If it is an accessor */
            else if (isAccessor(tok))
            {
                Statement statement = parseAccessor();

                /* TODO: Tets case has classes which null statement, will crash */
                program.addStatement(statement);
            }
            /* If it is a class */
            else if (symbol == SymbolType.CLASS)
            {
                Clazz clazz = parseClass();

                /* Add the class definition to the program */
                program.addStatement(clazz);
            }
            else
            {
                expect("parse(): Unknown '" ~ tok.getToken() ~ "'");
            }
        }

        gprintln("parse(): Leave", DebugType.WARNING);

        return program;
    }
}

unittest
{
    /* TODO: Add some unit tests */
    import std.file;
    import std.stdio;
    import compiler.lexer;

    isUnitTest = true;

    string sourceFile = "source/tlang/testing/basic1.t";
    
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

    

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        assert(currentLexer.performLex());
        
      
        Parser parser = new Parser(currentLexer.getTokens());
        parser.parse();
}


unittest
{
    /* TODO: Add some unit tests */
    import std.file;
    import std.stdio;
    import compiler.lexer;

    isUnitTest = true;

    string sourceFile = "source/tlang/testing/basic2.t";
    
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

    

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        assert(currentLexer.performLex());
        
      
        Parser parser = new Parser(currentLexer.getTokens());
        parser.parse();
}

