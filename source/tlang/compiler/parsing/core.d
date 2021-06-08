module compiler.parsing.core;

import gogga;
import std.conv : to;
import std.string : isNumeric, cmp;
import compiler.symbols.check;
import compiler.symbols.data;
import compiler.lexer : Token;
import core.stdc.stdlib;
import misc.exceptions : TError;
import compiler.parsing.exceptions;

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
    public void expect(SymbolType symbol, Token token)
    {
        /* TODO: Do checking here to see if token is a type of given symbol */
        SymbolType actualType = getSymbolType(token);
        bool isFine = actualType == symbol;

        /* TODO: Crash program if not */
        if (!isFine)
        {
            throw new SyntaxError(this, symbol, actualType);
            // expect("Expected symbol of type " ~ to!(string)(symbol) ~ " but got " ~ to!(
                    // string)(actualType) ~ " with " ~ token.toString());
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
            throw new TError(message);
            assert(false);
        }
        else
        {
            throw new TError(message);
            //exit(0); /* TODO: Exit code */  /* TODO: Version that returns or asserts for unit tests */
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

    public Assignment parseAssignment()
    {
        /* Generated Assignment statement */
        Assignment assignment;

        /* The identifier being assigned to */
        string identifier = getCurrentToken().getToken();
        nextToken();
        nextToken();
        gprintln(getCurrentToken());

        /* Expression */
        Expression assignmentExpression = parseExpression();


        assignment = new Assignment(identifier, assignmentExpression);

        /* TODO: Support for (a=1)? */
        /* Expect a semicolon */
        expect(SymbolType.SEMICOLON, getCurrentToken());
        nextToken();
        

        return assignment;
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
        /* Assignment */
        else if(type == SymbolType.ASSIGN)
        {
            previousToken();
            ret = parseAssignment();
        }
        /* Any other case */
        else
        {
            gprintln(getCurrentToken);
            expect("Error expected ( for var/func def");

        }
       



        return ret;
    }

    /* TODO: Implement me, and call me */
    private Struct parseStruct()
    {
        gprintln("parseStruct(): Enter", DebugType.WARNING);

        Struct generatedStruct;
        Statement[] statements;

        /* Consume the `struct` that caused `parseStruct` to be called */
        nextToken();

        /* Expect an identifier here (no dot) */
        string structName = getCurrentToken().getToken();
        expect(SymbolType.IDENT_TYPE, getCurrentToken());
        if(!isIdentifier_NoDot(getCurrentToken()))
        {
            expect("Identifier (for struct declaration) cannot be dotted");
        }
        
        /* Consume the name */
        nextToken();

        /* TODO: Here we will do a while loop */
        expect(SymbolType.OCURLY, getCurrentToken());
        nextToken();

        while(true)
        {
            /* Get current token */
            SymbolType symbolType = getSymbolType(getCurrentToken());

            /* The possibly valid returned struct member (Entity) */
            Statement structMember;

            /** TODO:
            * We only want to allow function definitions and variable
            * declarations here (WIP: for now without assignments)
            *
            * parseAccessor() supports those BUT it will also allow classes
            * and further structs - this we do not want and hence we should
            * filter out those (raise an error) on checking the type of
            * Entity returned by `parseAccessor()`
            */


            /* If it is a type */
            if (symbolType == SymbolType.IDENT_TYPE)
            {
                /* Might be a function, might be a variable, or assignment */
                structMember = parseName();
            }
            /* If it is an accessor */
            else if (isAccessor(getCurrentToken()))
            {
                structMember = parseAccessor();
            }
            /* If is is a modifier */
            else if(isModifier(getCurrentToken()))
            {
                structMember = parseInitScope();
            }
            /* If closing brace then exit */
            else if(symbolType == SymbolType.CCURLY)
            {
                break;
            }

            /* Ensure only function declaration or variable declaration */
            if(cast(Function)structMember)
            {

            }
            else if(cast(Variable)structMember)
            {
                /* Ensure that there is (WIP: for now) no assignment in the variable declaration */
                Variable variableDeclaration = cast(Variable)structMember;

                /* Raise error if an assignment is present */
                if(variableDeclaration.getAssignment())
                {
                    expect("Assignments not allowed in struct body");
                }
            }
            /**
            * Anything else that isn't a assignment-less variable declaration
            * or a function definition is an error
            */
            else
            {
                expect("Only function definitions and variable declarations allowed in struct body");
            }
            
            /* Append to struct's body */
            statements ~= structMember;
            
            

            

            /* TODO: Only allow variables here */
            /* TODO: Only allowe VariableDeclarations (maybe assignments idk) */
            /* TODO: Might, do what d does and allow function */
            /* TODO: Which is just a codegen trick and implicit thing really */
            /* TODO: I mean isn't OOP too lmao */

            
        }


        /* Generate a new Struct with the given body Statement(s) */
        generatedStruct = new Struct(structName);
        generatedStruct.addStatements(statements);
        
        /* Expect closing brace (sanity) */
        expect(SymbolType.CCURLY, getCurrentToken());

        /* Consume the closing curly brace */
        nextToken();


        gprintln("parseStruct(): Leave", DebugType.WARNING);

        return generatedStruct;
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
                /* Might be a function, might be a variable, or assignment */
                statements ~= parseName();
            }
            /* If it is an accessor */
            else if (isAccessor(tok))
            {
                statements ~= parseAccessor();
            }
            /* If it is a modifier */
            else if(isModifier(tok))
            {
                statements ~= parseInitScope();
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
            /* If it is a struct definition */
            else if(symbol == SymbolType.STRUCT)
            {
                /* Parse the struct and add it to the statements */
                statements ~= parseStruct();
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

    private InitScope getInitScope(Token token)
    {
        if(getSymbolType(token) == SymbolType.STATIC)
        {
            return InitScope.STATIC;
        }
        else
        {
            return InitScope.UNKNOWN;
        }
    }


    /* STATUS: Not being used yet */
    /**
    * Called in an occurence of the: `static x`
    */
    /* TODO: Anything that isn't static, is non-static => the false boolean should imply non-static */
    private Entity parseInitScope()
    {
        Entity entity;

        /* Save and consume the init-scope */
        InitScope initScope = getInitScope(getCurrentToken());
        nextToken();

        /* Get the current token's symbol type */
        SymbolType symbolType = getSymbolType(getCurrentToken());

        /**
        * TODO
        *
        * Topic of discussion: "What can be static?"
        *
        * Structs!
        *   As we might want them to be initted on class load or not (on instance initialization)
        * Classes
        *   Likewise a class in a class could be initted if static then on outer class load so would inner
        *   If not then only inner class loads on outer instantiation
        * Variables
        *   Initialize on class reference if static, however if not, then on instance initialization
        *
        *   Note: There are two meanings for static (if you take C for example, I might add a word for that, `global` rather)
        * Functions
        *   Journal entry describes this.
        *
        * Journal entry also describes this (/journal/static_keyword_addition/)
        */
        /* If class */
        if(symbolType == SymbolType.CLASS)
        {
            /* TODO: Set accessor on returned thing */
            entity = parseClass();
        }
        /* If struct */
        else if(symbolType == SymbolType.STRUCT)
        {
            /* TODO: Set accessor on returned thing */
            entity = parseStruct();
            gprintln("Poes"~to!(string)(entity));
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
            expect("Expected either function definition, variable declaration, struct definition or class definition");
        }

        entity.setModifierType(initScope);

        return entity;
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
        /* If struct */
        else if(symbolType == SymbolType.STRUCT)
        {
            /* TODO: Set accessor on returned thing */
            entity = parseStruct();
            gprintln("Poes"~to!(string)(entity));
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
        /* If static */
        else if(symbolType == SymbolType.STATIC)
        {
            entity = parseInitScope();
        }
        /* Error out */
        else
        {
            expect("Expected either function definition, variable declaration, struct definition or class definition");
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
                if(!isIdentifier_NoDot(getCurrentToken()))
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

        /* The expression to be returned */
        Expression[] retExpression;

        void addRetExp(Expression e)
        {
            retExpression ~= e;
        }

        Expression removeExp()
        {
            Expression poppedExp = retExpression[retExpression.length-1];
            retExpression.length--;

            return poppedExp;
        }

        bool hasExp()
        {
            return retExpression.length != 0;
        }

        void expressionStackSanityCheck()
        {
            /* If we don't have 1 on the stack */
            if(retExpression.length != 1)
            {
                gprintln(retExpression);
                expect("Expression parsing failed as we had remaining items on the expression parser stack or zero");
            }
        }

        /* TODO: Unless I am wrong we can do a check that retExp should always be length 1 */
        /* TODO: Makes sure that expressions like 1 1 don't wortk */
        /* TODO: It must always be consumed */

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

            gprintln(retExpression);

            /* If it is a number literal */
            if (symbol == SymbolType.NUMBER_LITERAL)
            { 
                /* TODO: Do number checking here to get correct NUmberLiteral */
                NumberLiteral numberLiteral = new NumberLiteral(getCurrentToken().getToken());
                
                /* Add expression to stack */
                addRetExp(numberLiteral);

                /* Get the next token */
                nextToken();
            }
            /* If it is a maths operator */
            else if (isMathOp(getCurrentToken()))
            {
                SymbolType operatorType = getSymbolType(getCurrentToken());

                /* TODO: Save operator, also pass to constructor */
                /* TODO: Parse expression or pass arithemetic (I think latter) */
                nextToken();

                OperatorExpression opExp;

                /* Check if unary or not (if so no expressions on stack) */
                if(!hasExp())
                {
                    Expression rhs = parseExpression();

                    /* Create UnaryExpression */
                    opExp = new UnaryOperatorExpression(operatorType, rhs);
                }
                /* If has, then binary */
                else
                {
                    /* Pop left-hand side expression */
                    /* TODO: We should have error checking for `removeExp()` */
                    /* TODO: Make it automatically exit if not enough exps */
                    Expression lhs = removeExp();

                    /* Parse expression (the right-hand side) */
                    Expression rhs = parseExpression();

                    /* Create BinaryOpertaor Expression */
                    opExp = new BinaryOperatorExpression(operatorType, lhs, rhs);
                }

                /* Add operator expression to stack */
                addRetExp(opExp);
            }
            /* If it is a string literal */
            else if (symbol == SymbolType.STRING_LITERAL)
            {
                /* Add the string to the stack */
                addRetExp(new StringExpression(getCurrentToken().getToken()));

                /* Get the next token */
                nextToken();
            }
            /* If it is an identifier */
            else if (symbol == SymbolType.IDENT_TYPE)
            {
                string identifier = getCurrentToken().getToken();

                nextToken();

                Expression toAdd;

                /* If the symbol is `(` then function call */
                if (getSymbolType(getCurrentToken()) == SymbolType.LBRACE)
                {
                    /* TODO: Implement function call parsing */
                    previousToken();
                    toAdd = parseFuncCall();
                }
                else
                {
                    /* TODO: Leave the token here */
                    /* TODO: Just leave it, yeah */
                    // expect("poes");
                    toAdd = new VariableExpression(identifier);
                }

                /* TODO: Change this later, for now we doing this */
                addRetExp(toAdd);
            }
            /* Detect if this expression is coming to an end, then return */
            else if (symbol == SymbolType.SEMICOLON || symbol == SymbolType.RBRACE || symbol == SymbolType.COMMA)
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
                addRetExp(parseExpression());

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


        gprintln(retExpression);
        gprintln("parseExpression(): Leave", DebugType.WARNING);

        /* TODO: DO check here for retExp.length = 1 */
        expressionStackSanityCheck();

        return retExpression[0];
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
        if(!isIdentifier_NoDot(getCurrentToken()))
        {
            expect("Class name in declaration cannot be path");
        }
        string className = getCurrentToken().getToken();
        gprintln("parseClass(): Class name found '" ~ className ~ "'");
        nextToken();

        generated = new Clazz(className);

        string[] inheritList;

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
                inheritList ~= getCurrentToken().getToken();
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








        /* TODO: Here we will do a while loop */
        expect(SymbolType.OCURLY, getCurrentToken());
        nextToken();

        Statement[] statements;

        while(true)
        {
            /* Get current token */
            SymbolType symbolType = getSymbolType(getCurrentToken());

            /* The possibly valid returned struct member (Entity) */
            Statement structMember;

            /** TODO:
            * We only want to allow function definitions and variable
            * declarations here (WIP: for now without assignments)
            *
            * parseAccessor() supports those BUT it will also allow classes
            * and further structs - this we do not want and hence we should
            * filter out those (raise an error) on checking the type of
            * Entity returned by `parseAccessor()`
            */


            /* If it is a type */
            if (symbolType == SymbolType.IDENT_TYPE)
            {
                /* Might be a function, might be a variable, or assignment */
                structMember = parseName();
            }
            /* If it is a class */
            else if(symbolType == SymbolType.CLASS)
            {
                structMember = parseClass();   
            }
            /* If it is a struct */
            else if(symbolType == SymbolType.STRUCT)
            {
                structMember = parseStruct();
            }
            /* If it is an accessor */
            else if (isAccessor(getCurrentToken()))
            {
                structMember = parseAccessor();
            }
            /* If is is a modifier */
            else if(isModifier(getCurrentToken()))
            {
                structMember = parseInitScope();
            }
            /* If closing brace then exit */
            else if(symbolType == SymbolType.CCURLY)
            {
                break;
            }
            else
            {
                expect("Only classes, structs, instance fields, static fields, functions allowed in class");
            }

            
            
            /* Append to struct's body */
            statements ~= structMember;
            
            

            

            /* TODO: Only allow variables here */
            /* TODO: Only allowe VariableDeclarations (maybe assignments idk) */
            /* TODO: Might, do what d does and allow function */
            /* TODO: Which is just a codegen trick and implicit thing really */
            /* TODO: I mean isn't OOP too lmao */

            
        }





        /* Add inherit list */
        generated.addInherit(inheritList);





        // /* TODO: Technically we should be more specific, this does too much */
        // /* Parse a body */
        // Statement[] statements = parseBody();
        generated.addStatements(statements);

        /* Parent each Statement to the container */
        parentToContainer(generated, statements);

        /* Pop off the ending `}` */
        nextToken();

        gprintln("parseClass(): Leave", DebugType.WARNING);

        return generated;
    }

    private void parentToContainer(Container container, Statement[] statements)
    {
        foreach(Statement statement; statements)
        {
            if(statement !is null)
            {
                statement.parentTo(container);
            }
        }
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

    private Expression parseFuncCall()
    {
        gprintln("parseFuncCall(): Enter", DebugType.WARNING);

        /* TODO: Save name */
        string functionName = getCurrentToken().getToken();

        Expression[] arguments;

        nextToken();

        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, getCurrentToken());
        nextToken();

        /* If next token is RBRACE we don't expect arguments */
        if(getSymbolType(getCurrentToken()) == SymbolType.RBRACE)
        {
            
        }
        /* If not expect arguments */
        else
        {
            while(true)
            {
                /* Get the Expression */
                Expression exp = parseExpression();

                /* Add it to list */
                arguments ~= exp;

                /* Check if we exiting */
                if(getSymbolType(getCurrentToken()) == SymbolType.RBRACE)
                {
                    break;
                }
                /* If comma expect more */
                else if(getSymbolType(getCurrentToken()) == SymbolType.COMMA)
                {
                    nextToken();
                    /* TODO: If rbrace after then error, so save boolean */
                }
                /* TODO: Add else, could have exited on `;` which is invalid closing */
                else
                {
                    expect("Function call closed on ;, invalid");
                }
            }
        }

       
        nextToken();

        gprintln("parseFuncCall(): Leave", DebugType.WARNING);

        return new FunctionCall(functionName, arguments);
    }

    /* Almost like parseBody but has more */
    /**
    * TODO: For certain things like `parseClass` we should
    * keep track of what level we are at as we shouldn't allow
    * one to define classes within functions
    */
    /* TODO: Variables should be allowed to have letters in them and underscores */
    public Module parse()
    {
        gprintln("parse(): Enter", DebugType.WARNING);

        Module modulle;

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

        /* Initialize Module */
        modulle = new Module(programName);

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
                /* Might be a function, might be a variable, or assignment */
                Statement statement = parseName();
                
                /**
                * If it is an Entity then mark it as static
                * as all Entities at module-level are static
                */
                if(cast(Entity)statement)
                {
                    Entity entity = cast(Entity)statement;
                    entity.setModifierType(InitScope.STATIC);
                }

                modulle.addStatement(statement);
            }
            /* If it is an accessor */
            else if (isAccessor(tok))
            {
                Entity entity = parseAccessor();

                /* Everything at the Module level is static */
                entity.setModifierType(InitScope.STATIC);

                /* TODO: Tets case has classes which null statement, will crash */
                modulle.addStatement(entity);
            }
            /* If it is a class */
            else if (symbol == SymbolType.CLASS)
            {
                Clazz clazz = parseClass();

                /* Everything at the Module level is static */
                clazz.setModifierType(InitScope.STATIC);

                /* Add the class definition to the program */
                modulle.addStatement(clazz);
            }
            /* If it is a struct definition */
            else if(symbol == SymbolType.STRUCT)
            {
                Struct ztruct = parseStruct();

                /* Everything at the Module level is static */
                ztruct.setModifierType(InitScope.STATIC);

                /* Add the struct definition to the program */
                modulle.addStatement(ztruct);
            }
            else
            {
                expect("parse(): Unknown '" ~ tok.getToken() ~ "'");
            }
        }

        gprintln("parse(): Leave", DebugType.WARNING);

        /* Parent each Statement to the container (the module) */
        parentToContainer(modulle, modulle.getStatements());

        return modulle;
    }
}

// unittest
// {
//     /* TODO: Add some unit tests */
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;

//     isUnitTest = true;

//     string sourceFile = "source/tlang/testing/basic1.t";
    
//         File sourceFileFile;
//         sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//         ulong fileSize = sourceFileFile.size();
//         byte[] fileBytes;
//         fileBytes.length = fileSize;
//         fileBytes = sourceFileFile.rawRead(fileBytes);
//         sourceFileFile.close();

    

//         /* TODO: Open source file */
//         string sourceCode = cast(string)fileBytes;
//         // string sourceCode = "hello \"world\"|| ";
//         //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
//         // string sourceCode = "hello;";
//         Lexer currentLexer = new Lexer(sourceCode);
//         assert(currentLexer.performLex());
        
      
//         Parser parser = new Parser(currentLexer.getTokens());
//         parser.parse();
// }


unittest
{
    /* TODO: Add some unit tests */
    import std.file;
    import std.stdio;
    import compiler.lexer;

    isUnitTest = true;

    // string sourceFile = "source/tlang/testing/basic1.t";
    
    //     File sourceFileFile;
    //     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    //     ulong fileSize = sourceFileFile.size();
    //     byte[] fileBytes;
    //     fileBytes.length = fileSize;
    //     fileBytes = sourceFileFile.rawRead(fileBytes);
    //     sourceFileFile.close();

    

    //     /* TODO: Open source file */
    //     string sourceCode = cast(string)fileBytes;
    //     // string sourceCode = "hello \"world\"|| ";
    //     //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
    //     // string sourceCode = "hello;";
    //     Lexer currentLexer = new Lexer(sourceCode);
    //     assert(currentLexer.performLex());
        
      
    //     Parser parser = new Parser(currentLexer.getTokens());
    //     parser.parse();
}

unittest
{

    import std.file;
    import std.stdio;
    import compiler.lexer;

    string sourceFile = "source/tlang/testing/simple1_module_positive.t";
    
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
    
    try
    {
        Module modulle = parser.parse();

        assert(cmp(modulle.getName(), "myModule")==0);
    }
    catch(TError)
    {
        assert(false);
    }
}

/**
* Naming test for Entity recognition
*/
unittest
{
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.typecheck.core;

    string sourceFile = "source/tlang/testing/simple2_name_recognition.t";
    
    File sourceFileFile;
    sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();



    /* TODO: Open source file */
    string sourceCode = cast(string)fileBytes;
    Lexer currentLexer = new Lexer(sourceCode);
    assert(currentLexer.performLex());
    
    
    Parser parser = new Parser(currentLexer.getTokens());
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be myModule */
        assert(cmp(modulle.getName(), "myModule")==0);
        TypeChecker tc = new TypeChecker(modulle);

        /**
        * There should exist two module-level classes
        *
        * 1. Attempt resolving the two without a full-path (relative to module)
        * 2. Attempt resolving the two with a full-path
        */

        /* There should exist two Module-level classes named `myClass1` and `myClass2` */
        Entity entity1_rel = tc.getResolver().resolveBest(modulle, "myClass1");
        Entity entity2_rel = tc.getResolver().resolveBest(modulle, "myClass2");
        assert(entity1_rel);
        assert(entity2_rel);

        /* Resolve using full-path instead */
        Entity entity1_fp = tc.getResolver().resolveBest(modulle, "myModule.myClass1");
        Entity entity2_fp = tc.getResolver().resolveBest(modulle, "myModule.myClass2");
        assert(entity1_fp);
        assert(entity2_fp);

        /* These should match respectively */
        assert(entity1_rel == entity1_fp);
        assert(entity2_rel == entity2_fp);

        /* These should all be classes */
        Clazz clazz1 = cast(Clazz)entity1_fp;
        Clazz clazz2 = cast(Clazz)entity2_fp;
        assert(clazz1);
        assert(clazz1);
        
        


        /**
        * Resolve members of myClass1
        *
        * 1. Resolve full-path
        * 2. Resolve relative to myClass1
        * 3. Resolve relative to module (incorrect)
        * 4. Resolve relative to module (correct)
        * 5. Resolve relative to myClass2 (resolves upwards)
        */
        Entity myClass1_myClass2_1 = tc.getResolver().resolveBest(modulle, "myModule.myClass1.myClass2");
        Entity myClass1_myClass2_2 = tc.getResolver().resolveBest(clazz1, "myClass2");
        Entity myClass2 = tc.getResolver().resolveBest(modulle, "myClass2");
        Entity myClass1_myClass2_4 = tc.getResolver().resolveBest(modulle, "myClass1.myClass2");
        Entity myClass1_myClass2_5 = tc.getResolver().resolveBest(clazz2, "myClass1.myClass2");
        
        /**
        * All the above should exist
        */
        assert(myClass1_myClass2_1);
        assert(myClass1_myClass2_2);
        assert(myClass2);
        assert(myClass1_myClass2_4);
        assert(myClass1_myClass2_5);

        /**
        * They should all be classes
        */
        Clazz c_myClass1_myClass2_1 = cast(Clazz)myClass1_myClass2_1;
        Clazz c_myClass1_myClass2_2 = cast(Clazz)myClass1_myClass2_2;
        Clazz c_myClass2 = cast(Clazz)myClass2;
        Clazz c_myClass1_myClass2_4 = cast(Clazz)myClass1_myClass2_4;
        Clazz c_myClass1_myClass2_5 = cast(Clazz)myClass1_myClass2_5;

        /**
        * These should all be equal `myClass1.myClass2`
        */
        assert(c_myClass1_myClass2_1 == c_myClass1_myClass2_2);
        assert(c_myClass1_myClass2_2 == myClass1_myClass2_4);
        assert(myClass1_myClass2_4 == myClass1_myClass2_5);

        /**
        * myClass1.myClass2 != myClass2
        *
        * myClass1.myClass2.inner should exist in myClass1.myClass2
        * myClass2.outer should exist in myClass2
        *
        * Vice-versa of the above should not be true
        */
        assert(myClass1_myClass2_5 != myClass2);

        Entity innerVariable = tc.getResolver().resolveBest(c_myClass1_myClass2_5, "inner");
        Entity outerVariable = tc.getResolver().resolveBest(c_myClass2, "outer");
        assert(innerVariable !is null);
        assert(outerVariable !is null);

        
        



        
        

        

        


        
    }
    catch(TError)
    {
        assert(false);
    }
}