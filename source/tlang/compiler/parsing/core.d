module tlang.compiler.parsing.core;

import gogga;
import std.conv : to, ConvException;
import std.string : isNumeric, cmp;
import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import tlang.compiler.lexer.core;
import core.stdc.stdlib;
import misc.exceptions : TError;
import tlang.compiler.parsing.exceptions;

bool isUnitTest;

// TODO: Technically we could make a core parser etc
public final class Parser
{
    /** 
     * Tokens management
     */
    private LexerInterface lexer;

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
            throw new SyntaxError(this, symbol, token);
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
     * Constructs a new parser with the given lexer
     * from which tokens can be sourced from
     *
     * Params:
     *   lexer = the token source
     */
    this(LexerInterface lexer)
    {
        this.lexer = lexer;
    }

    /** 
     * Given a type of `Statement` to look for and a `Container` of
     * which to search with in. This method will recursively search
     * down the given container and look for any statements which
     * are a kind-of (`isBaseOf`) the requested type. it will return
     * an array of `Statement` (`Statement[]`) of the matches.
     *
     * The container itself is not considered in this type check.
     *
     * Params:
     *   statementType = the kind-of statement to look for
     *   from = the `Container` to search within
     * Returns: a `Statement[]` of matches
     */
    private static Statement[] findOfType(TypeInfo_Class statementType, Container from)
    {
        Statement[] matches;

        Statement[] bodyStatements = from.getStatements();
        foreach(Statement bodyStmt; bodyStatements)
        {
            if(cast(Container)bodyStmt)
            {
                matches ~= findOfType(statementType, cast(Container)bodyStmt);
            }

            if(statementType.isBaseOf(typeid(bodyStmt)))
            {
                matches ~= [bodyStmt];
            }
        }

        return matches;
    }

    /** 
     * Given a type of `Statement` to look for and a `Container` of
     * which to search with in. This method will recursively search
     * down the given container and look for any statements which
     * are a kind-of (`isBaseOf`) the requested type. It will return
     * `true` if any macthes are found.
     *
     * The container itself is not considered in this type check.
     *
     * Params:
     *   statementType = the kind-of statement to look for
     *   from = the `Container` to search within
     * Returns: `true` if at least one match is found, `false`
     * otherwise
     */
    private static bool existsWithin(TypeInfo_Class statementType, Container from)
    {
        return findOfType(statementType, from).length != 0;
    }

    /**
    * Parses if statements
    *
    * TODO: Check kanban
    * TOOD: THis should return something
    */
    private IfStatement parseIf()
    {
        gprintln("parseIf(): Enter", DebugType.WARNING);

        IfStatement ifStmt;
        Branch[] branches;

        while (lexer.hasTokens())
        {
            Expression currentBranchCondition;
            Statement[] currentBranchBody;

            /* This will only be called once (it is what caused a call to parseIf()) */
            if (getSymbolType(lexer.getCurrentToken()) == SymbolType.IF)
            {
                /* Pop off the `if` */
                lexer.nextToken();

                /* Expect an opening brace `(` */
                expect(SymbolType.LBRACE, lexer.getCurrentToken());
                lexer.nextToken();

                /* Parse an expression (for the condition) */
                currentBranchCondition = parseExpression();
                expect(SymbolType.RBRACE, lexer.getCurrentToken());

                /* Opening { */
                lexer.nextToken();
                expect(SymbolType.OCURLY, lexer.getCurrentToken());

                /* Parse the if' statement's body AND expect a closing curly */
                currentBranchBody = parseBody();
                expect(SymbolType.CCURLY, lexer.getCurrentToken());
                lexer.nextToken();

                /* Create a branch node */
                Branch branch = new Branch(currentBranchCondition, currentBranchBody);
                parentToContainer(branch, currentBranchBody);
                branches ~= branch;
            }
            /* If we get an else as the next symbol */
            else if (getSymbolType(lexer.getCurrentToken()) == SymbolType.ELSE)
            {
                /* Pop off the `else` */
                lexer.nextToken();

                /* Check if we have an `if` after the `{` (so an "else if" statement) */
                if (getSymbolType(lexer.getCurrentToken()) == SymbolType.IF)
                {
                    /* Pop off the `if` */
                    lexer.nextToken();

                    /* Expect an opening brace `(` */
                    expect(SymbolType.LBRACE, lexer.getCurrentToken());
                    lexer.nextToken();

                    /* Parse an expression (for the condition) */
                    currentBranchCondition = parseExpression();
                    expect(SymbolType.RBRACE, lexer.getCurrentToken());

                    /* Opening { */
                    lexer.nextToken();
                    expect(SymbolType.OCURLY, lexer.getCurrentToken());

                    /* Parse the if' statement's body AND expect a closing curly */
                    currentBranchBody = parseBody();
                    expect(SymbolType.CCURLY, lexer.getCurrentToken());
                    lexer.nextToken();

                    /* Create a branch node */
                    Branch branch = new Branch(currentBranchCondition, currentBranchBody);
                    parentToContainer(branch, currentBranchBody);
                    branches ~= branch;
                }
                /* Check for opening curly (just an "else" statement) */
                else if (getSymbolType(lexer.getCurrentToken()) == SymbolType.OCURLY)
                {
                    /* Parse the if' statement's body (starting with `{` AND expect a closing curly */
                    currentBranchBody = parseBody();
                    expect(SymbolType.CCURLY, lexer.getCurrentToken());
                    lexer.nextToken();

                    /* Create a branch node */
                    Branch branch = new Branch(null, currentBranchBody);
                    parentToContainer(branch, currentBranchBody);
                    branches ~= branch;

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

        /* Create the if statement with the branches */
        ifStmt = new IfStatement(branches);

        /* Parent the branches to the IfStatement */
        parentToContainer(ifStmt, cast(Statement[])branches);

        return ifStmt;
    }

    private WhileLoop parseWhile()
    {
        gprintln("parseWhile(): Enter", DebugType.WARNING);

        Expression branchCondition;
        Statement[] branchBody;

        /* Pop off the `while` */
        lexer.nextToken();

        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Parse an expression (for the condition) */
        branchCondition = parseExpression();
        expect(SymbolType.RBRACE, lexer.getCurrentToken());

        /* Opening { */
        lexer.nextToken();
        expect(SymbolType.OCURLY, lexer.getCurrentToken());

        /* Parse the while' statement's body AND expect a closing curly */
        branchBody = parseBody();
        expect(SymbolType.CCURLY, lexer.getCurrentToken());
        lexer.nextToken();


        /* Create a Branch node coupling the condition and body statements */
        Branch branch = new Branch(branchCondition, branchBody);

        /* Parent the branchBody to the branch */
        parentToContainer(branch, branchBody);

        /* Create the while loop with the single branch */
        WhileLoop whileLoop = new WhileLoop(branch);

        /* Parent the branch to the WhileLoop */
        parentToContainer(whileLoop, [branch]);

        gprintln("parseWhile(): Leave", DebugType.WARNING);

        return whileLoop;
    }

    private WhileLoop parseDoWhile()
    {
        gprintln("parseDoWhile(): Enter", DebugType.WARNING);

        Expression branchCondition;
        Statement[] branchBody;

        /* Pop off the `do` */
        lexer.nextToken();

        /* Expect an opening curly `{` */
        expect(SymbolType.OCURLY, lexer.getCurrentToken());

        /* Parse the do-while statement's body AND expect a closing curly */
        branchBody = parseBody();
        expect(SymbolType.CCURLY, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect a `while` */
        expect(SymbolType.WHILE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Parse the condition */
        branchCondition = parseExpression();
        expect(SymbolType.RBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect a semicolon */
        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        /* Create a Branch node coupling the condition and body statements */
        Branch branch = new Branch(branchCondition, branchBody);

        /* Parent the branchBody to the branch */
        parentToContainer(branch, branchBody);

        /* Create the while loop with the single branch and marked as a do-while loop */
        WhileLoop whileLoop = new WhileLoop(branch, true);

        /* Parent the branch to the WhileLoop */
        parentToContainer(whileLoop, [branch]);

        gprintln("parseDoWhile(): Leave", DebugType.WARNING);

        return whileLoop;
    }

    // TODO: Finish implementing this
    // TODO: We need to properly parent and build stuff
    // TODO: We ASSUME there is always pre-run, condition and post-iteration
    public ForLoop parseFor()
    {
        gprintln("parseFor(): Enter", DebugType.WARNING);

        Expression branchCondition;
        Statement[] branchBody;

        /* Pop of the token `for` */
        lexer.nextToken();

        /* Expect an opening smooth brace `(` */
        expect(SymbolType.LBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect a single Statement */
        // TODO: Make optional, add parser lookahead check
        Statement preRunStatement = parseStatement();
        
        /* Expect an expression */
        // TODO: Make optional, add parser lookahead check
        branchCondition = parseExpression();

        /* Expect a semi-colon, then move on */
        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect a post-iteration statement with `)` as terminator */
        // TODO: Make optional, add parser lookahead check
        Statement postIterationStatement = parseStatement(SymbolType.RBRACE);
        
        /* Expect an opening curly `{` and parse the body */
        expect(SymbolType.OCURLY, lexer.getCurrentToken());
        branchBody = parseBody();

        /* Expect a closing curly and move on */
        expect(SymbolType.CCURLY, lexer.getCurrentToken());
        lexer.nextToken();

        gprintln("Yo: "~lexer.getCurrentToken().toString());

        /* Create the Branch coupling the body statements (+post iteration statement) and condition */
        Branch forBranch = new Branch(branchCondition, branchBody~postIterationStatement);

        /* Create the for loop */
        ForLoop forLoop = new ForLoop(forBranch, preRunStatement);

        // TODO: Set `forLoop.hasPostIterate`

        /* Parent the pre-run statement to its for loop */
        parentToContainer(forLoop, [preRunStatement]);

        /* Parent the body of the branch (body statements + post iteration statement) */
        parentToContainer(forBranch, branchBody~postIterationStatement);

        /* Parent the Branch to its for loop */
        parentToContainer(forLoop, [forBranch]);

        gprintln("parseFor(): Leave", DebugType.WARNING);

        return forLoop;
    }

    public VariableAssignmentStdAlone parseAssignment(SymbolType terminatingSymbol = SymbolType.SEMICOLON)
    {
        /* Generated Assignment statement */
        VariableAssignmentStdAlone assignment;

        /* The identifier being assigned to */
        string identifier = lexer.getCurrentToken().getToken();
        lexer.nextToken();
        lexer.nextToken();
        gprintln(lexer.getCurrentToken());

        /* Expression */
        Expression assignmentExpression = parseExpression();


        assignment = new VariableAssignmentStdAlone(identifier, assignmentExpression);

        /* TODO: Support for (a=1)? */
        /* Expect a the terminating symbol */
        // expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        expect(terminatingSymbol, lexer.getCurrentToken());

        /* Move off terminating symbol */
        lexer.nextToken();
        

        return assignment;
    }

    public Statement parseName(SymbolType terminatingSymbol = SymbolType.SEMICOLON)
    {
        Statement ret;

        /* Save the name or type */
        string nameTYpe = lexer.getCurrentToken().getToken();
        gprintln("parseName(): Current token: "~lexer.getCurrentToken().toString());

        /* TODO: The problem here is I don't want to progress the token */

        /* Get next token */
        lexer.nextToken();
        SymbolType type = getSymbolType(lexer.getCurrentToken());

        /* If we have `(` then function call */
        if(type == SymbolType.LBRACE)
        {
            lexer.previousToken();
            FunctionCall funcCall = parseFuncCall();
            ret = funcCall;

            /* Set the flag to say this is a statement-level function call */
            funcCall.makeStatementLevel();

             /* Expect a semi-colon */
            expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
            lexer.nextToken();
        }
        /**
        * Either we have:
        *
        * 1. `int ptr` (and we looked ahead to `ptr`)
        * 2. `int* ptr` (and we looked ahead to `*`)
        * 3. `int[] thing` (and we looked ahead to `[`)
        */
        /* If we have an identifier/type then declaration */
        else if(type == SymbolType.IDENT_TYPE || type == SymbolType.STAR || type == SymbolType.OBRACKET)
        {
            lexer.previousToken();
            ret = parseTypedDeclaration();

            /* If it is a function definition, then do nothing */
            if(cast(Function)ret)
            {
                // The ending `}` would have already been consumed
            }
            /* If it is a variable declaration then */
            else if(cast(Variable)ret)
            {
                /* Expect a semicolon and consume it */
                expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
                lexer.nextToken();
            }
            /* If it is an arrau assignment */
            else if(cast(ArrayAssignment)ret)
            {
                /* Expect a semicolon and consume it */
                expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
                lexer.nextToken();
            }
            /* This should never happen */
            else
            {
                assert(false);
            }
        }
        /* Assignment */
        else if(type == SymbolType.ASSIGN)
        {
            lexer.previousToken();
            ret = parseAssignment(terminatingSymbol);
        }
        /* Any other case */
        else
        {
            gprintln(lexer.getCurrentToken());
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
        lexer.nextToken();

        /* Expect an identifier here (no dot) */
        string structName = lexer.getCurrentToken().getToken();
        expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
        if(!isIdentifier_NoDot(lexer.getCurrentToken()))
        {
            expect("Identifier (for struct declaration) cannot be dotted");
        }
        
        /* Consume the name */
        lexer.nextToken();

        /* TODO: Here we will do a while loop */
        expect(SymbolType.OCURLY, lexer.getCurrentToken());
        lexer.nextToken();

        while(true)
        {
            /* Get current token */
            SymbolType symbolType = getSymbolType(lexer.getCurrentToken());

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
            else if (isAccessor(lexer.getCurrentToken()))
            {
                structMember = parseAccessor();
            }
            /* If is is a modifier */
            else if(isModifier(lexer.getCurrentToken()))
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
        expect(SymbolType.CCURLY, lexer.getCurrentToken());

        /* Consume the closing curly brace */
        lexer.nextToken();


        gprintln("parseStruct(): Leave", DebugType.WARNING);

        return generatedStruct;
    }

    private ReturnStmt parseReturn()
    {
        ReturnStmt returnStatement;

        /* Move from `return` onto start of expression */
        lexer.nextToken();

        // TODO: Check if semicolon here (no expression) else expect expression

        /* If the next token after `return` is a `;` then it is an expressionless return */
        if(getSymbolType(lexer.getCurrentToken()) == SymbolType.SEMICOLON)
        {
            /* Create the ReturnStmt (without an expression) */
            returnStatement = new ReturnStmt();
        }
        /* Else, then look for an expression */
        else
        {
            /* Parse the expression till termination */
            Expression returnExpression = parseExpression();

            /* Expect a semi-colon as the terminator */
            gprintln(lexer.getCurrentToken());
            expect(SymbolType.SEMICOLON, lexer.getCurrentToken());

            /* Create the ReturnStmt */
            returnStatement = new ReturnStmt(returnExpression);
        }

        /* Move off of the terminator */
        lexer.nextToken();

        return returnStatement;
    }

    private Statement[] parseBody()
    {
        gprintln("parseBody(): Enter", DebugType.WARNING);

        /* TODO: Implement body parsing */
        Statement[] statements;

        /* Consume the `{` symbol */
        lexer.nextToken();

        /**
        * If we were able to get a closing token, `}`, then
        * this will be set to true, else it will be false by
        * default which implies we ran out of tokens before
        * we could close te body which is an error we do throw
        */
        bool closedBeforeExit;

        while (lexer.hasTokens())
        {
            /* Get the token */
            Token tok = lexer.getCurrentToken();
            SymbolType symbol = getSymbolType(tok);

            gprintln("parseBody(): SymbolType=" ~ to!(string)(symbol));

    
            /* If it is a class definition */
            if(symbol == SymbolType.CLASS)
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
            /* If it is closing the body `}` */
            else if(symbol == SymbolType.CCURLY)
            {
                gprintln("parseBody(): Exiting body by }", DebugType.WARNING);

                closedBeforeExit = true;
                break;
            }
            else
            {
                statements ~= parseStatement();
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
        InitScope initScope = getInitScope(lexer.getCurrentToken());
        lexer.nextToken();

        /* Get the current token's symbol type */
        SymbolType symbolType = getSymbolType(lexer.getCurrentToken());

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
        AccessorType accessorType = getAccessorType(lexer.getCurrentToken());
        lexer.nextToken();

        /* TODO: Only allow, private, public, protected */
        /* TODO: Pass this to call for class prsewr or whatever comes after the accessor */

        /* Get the current token's symbol type */
        SymbolType symbolType = getSymbolType(lexer.getCurrentToken());

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
        VariableParameter[] params;
    }

    private funcDefPair parseFuncDef(bool wantsBody = true)
    {
        gprintln("parseFuncDef(): Enter", DebugType.WARNING);

        Statement[] statements;
        VariableParameter[] parameterList;
        funcDefPair bruh;
        

        /* Consume the `(` token */
        lexer.nextToken();

        /* Count for number of parameters processed */
        ulong parameterCount;

        /* Expecting more arguments */
        bool moreArgs;

        /* Get command-line arguments */
        while (lexer.hasTokens())
        {
            /* Check if the first thing is a type */
            if(getSymbolType(lexer.getCurrentToken()) == SymbolType.IDENT_TYPE)
            {
                /* Get the type */
                TypedEntity bogusEntity = cast(TypedEntity)parseTypedDeclaration(false, false, false, true);
                string type = bogusEntity.getType();

                /* Get the identifier (This CAN NOT be dotted) */
                expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
                if(!isIdentifier_NoDot(lexer.getCurrentToken()))
                {
                    expect("Identifier can not be path");
                }
                string identifier = lexer.getCurrentToken().getToken();
                lexer.nextToken();


                /* Add the local variable (parameter variable) */
                parameterList ~= new VariableParameter(type, identifier);

                moreArgs = false;

                parameterCount++;
            }
            /* If we get a comma */
            else if(getSymbolType(lexer.getCurrentToken()) == SymbolType.COMMA)
            {
                /* Consume the `,` */
                lexer.nextToken();

                moreArgs = true;
            }
            /* Check if it is a closing brace */
            else if(getSymbolType(lexer.getCurrentToken()) == SymbolType.RBRACE)
            {
                /* Make sure we were not expecting more arguments */
                if(!moreArgs)
                {
                    /* Consume the `)` */
                    lexer.nextToken();
                    break;
                }
                /* Error out if we were and we prematurely ended */
                else
                {
                    expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
                }
            }
            /* Error out */
            else
            {
                expect("Expected either type or )");
            }
        }

        /* If a body is required then allow it */
        if(wantsBody)
        {
            expect(SymbolType.OCURLY, lexer.getCurrentToken());

            /* Parse the body (and it leaves ONLY when it gets the correct symbol, no expect needed) */
            statements = parseBody();

            /* TODO: We should now run through the statements in the body and check for return */
            for(ulong i = 0; i < statements.length; i++)
            {
                Statement curStatement = statements[i];

                /* If we find a return statement */
                if(cast(ReturnStmt)curStatement)
                {
                    /* If it is not the last statement, throw an error */
                    if(i != statements.length-1)
                    {
                        expect("A return statement must be the last statement of a function's body");
                    }
                }
            }

            lexer.nextToken();
        }
        /* If no body is requested */
        else
        {
            expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        }

        gprintln("ParseFuncDef: Parameter count: " ~ to!(string)(parameterCount));
        gprintln("parseFuncDef(): Leave", DebugType.WARNING);

        bruh.bodyStatements = statements;
        bruh.params = parameterList;

        return bruh;
    }


    /**
    * Only a subset of expressions are parsed without coming after
    * an assignment, functioncall parameters etc
    *
    * Therefore instead of mirroring a lot fo what is in expression, for now atleast
    * I will support everything using discard
    *
    * TODO: Remove discard and implement the needed mirrors
    */
    private DiscardStatement parseDiscard()
    {
        /* Consume the `discard` */
        lexer.nextToken();

        /* Parse the following expression */
        Expression expression = parseExpression();

        /* Expect a semi-colon */
        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        /* Create a `discard` statement */
        DiscardStatement discardStatement = new DiscardStatement(expression);

        return discardStatement;
    }

    /**
    * Parses the `new Class()` expression
    */


    private CastedExpression parseCast()
    {
        CastedExpression castedExpression;

        /* Consume the `cast` */
        lexer.nextToken();

        /* Expect an `(` open brace */
        expect(SymbolType.LBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /** 
         * Expect a type
         *
         * The way we do this is to re-use the logic
         * that `parseTypedDeclaration()` uses but we
         * ask it to not parse further than the last token
         * constituting the type (i.e. before starting to
         * parse the identifier token).
         *
         * It then will return a bogus `TypedEntity` with
         * a verfiable bogus name `BOGUS_NAME_STOP_SHORT_OF_IDENTIFIER_TYPE_FETCH` (TODO: Make sure we use this)
         * which means we can call `getType()` and extract
         * the type string
         */
        TypedEntity bogusEntity = cast(TypedEntity)parseTypedDeclaration(false, false, false, true);
        assert(bogusEntity);
        string toType = bogusEntity.getType();

        /* Expect a `)` closing brace */
        expect(SymbolType.RBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Get the expression to cast */
        Expression uncastedExpression = parseExpression();

        
        castedExpression = new CastedExpression(toType, uncastedExpression);

        return castedExpression;
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


        /** 
         * Helper methods
         *
         * (TODO: These should be moved elsewhere)
         */
        bool isFloatLiteral(string numberLiteral)
        {
            import std.string : indexOf;
            bool isFloat = indexOf(numberLiteral, ".") > -1; 
            return isFloat;
        }


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
            SymbolType symbol = getSymbolType(lexer.getCurrentToken());

            gprintln(retExpression);

            /* If it is a number literal */
            if (symbol == SymbolType.NUMBER_LITERAL)
            { 
                string numberLiteralStr = lexer.getCurrentToken().getToken();
                NumberLiteral numberLiteral;

                // If floating point literal
                if(isFloatLiteral(numberLiteralStr))
                {
                    // TODO: Issue #94, siiliar to below for integers
                    numberLiteral = new FloatingLiteral(lexer.getCurrentToken().getToken());
                }
                // Else, then an integer literal
                else
                {
                    // TODO: Issue #94, we should be checking the range here
                    // ... along with any explicit encoders and setting it
                    // ... for now default to SIGNED_INTEGER.
                    IntegerLiteralEncoding chosenEncoding;
                    // TODO (X-platform): Use `size_t` here
                    ulong literalValue;


                    
                    
                    // TODO: Add a check for the `U`, `UL` stuff here
                    import std.algorithm.searching : canFind;
                    // Explicit integer encoding (unsigned long)
                    if(canFind(numberLiteralStr, "UL"))
                    {
                        chosenEncoding = IntegerLiteralEncoding.UNSIGNED_LONG;

                        // Strip the `UL` away
                        numberLiteralStr = numberLiteralStr[0..numberLiteralStr.length-2];
                    }
                    // Explicit integer encoding (signed long)
                    else if(canFind(numberLiteralStr, "L"))
                    {
                        chosenEncoding = IntegerLiteralEncoding.SIGNED_LONG;

                        // Strip the `L` away
                        numberLiteralStr = numberLiteralStr[0..numberLiteralStr.length-1];
                    }
                    // Explicit integer encoding (unsigned int)
                    else if(canFind(numberLiteralStr, "UI"))
                    {
                        chosenEncoding = IntegerLiteralEncoding.UNSIGNED_INTEGER;

                        // Strip the `UI` away
                        numberLiteralStr = numberLiteralStr[0..numberLiteralStr.length-2];
                    }
                    // Explicit integer encoding (signed int)
                    else if(canFind(numberLiteralStr, "I"))
                    {
                        chosenEncoding = IntegerLiteralEncoding.SIGNED_INTEGER;

                        // Strip the `I` away
                        numberLiteralStr = numberLiteralStr[0..numberLiteralStr.length-1];
                    }
                    else
                    {
                        try
                        {
                            // TODO (X-platform): Use `size_t` here
                            literalValue = to!(ulong)(numberLiteralStr);
                            

                            // Signed integer range [0, 2_147_483_647]
                            if(literalValue >= 0 && literalValue <= 2_147_483_647)
                            {
                                chosenEncoding = IntegerLiteralEncoding.SIGNED_INTEGER;
                            }
                            // Signed long range [2_147_483_648, 9_223_372_036_854_775_807]
                            else if(literalValue >= 2_147_483_648 && literalValue <= 9_223_372_036_854_775_807)
                            {
                                chosenEncoding = IntegerLiteralEncoding.SIGNED_LONG;
                            }
                            // Unsigned long range [9_223_372_036_854_775_808, 18_446_744_073_709_551_615]
                            else
                            {
                                chosenEncoding = IntegerLiteralEncoding.UNSIGNED_LONG;
                            }
                        }
                        catch(ConvException e)
                        {
                            throw new ParserException(this, ParserException.ParserErrorType.LITERAL_OVERFLOW, "Literal '"~numberLiteralStr~"' would overflow");
                        }
                    }

                    numberLiteral = new IntegerLiteral(numberLiteralStr, chosenEncoding);
                }
                
                /* Add expression to stack */
                addRetExp(numberLiteral);

                /* Get the next token */
                lexer.nextToken();
            }
            /* If it is a cast operator */
            else if(symbol == SymbolType.CAST)
            {
                CastedExpression castedExpression = parseCast();
                addRetExp(castedExpression);
            }
            /* If it is a maths operator */
            /* TODO: Handle all operators here (well most), just include bit operators */
            else if (isMathOp(lexer.getCurrentToken()) || isBinaryOp(lexer.getCurrentToken()))
            {
                SymbolType operatorType = getSymbolType(lexer.getCurrentToken());

                /* TODO: Save operator, also pass to constructor */
                /* TODO: Parse expression or pass arithemetic (I think latter) */
                lexer.nextToken();

                OperatorExpression opExp;

                /* Check if unary or not (if so no expressions on stack) */
                if(!hasExp())
                {
                    /* Only `*`, `+` and `-` are valid or `~` */
                    if(operatorType == SymbolType.STAR || operatorType == SymbolType.ADD || operatorType == SymbolType.SUB || operatorType == SymbolType.TILDE)
                    {
                        /* Parse the expression following the unary operator */
                        Expression rhs = parseExpression();

                        /* Create UnaryExpression comprised of the operator and the right-hand side expression */
                        opExp = new UnaryOperatorExpression(operatorType, rhs);
                    }
                    /* Support for ampersand (&) */
                    else if(operatorType == SymbolType.AMPERSAND)
                    {
                        /* Expression can only be a `VariableExpression` which accounts for Function Handles and Variable Identifiers */
                        Expression rhs = parseExpression();
                        gprintln("hhshhshshsh");
                        if(cast(VariableExpression)rhs)
                        {
                            /* Create UnaryExpression comprised of the operator and the right-hand side expression */
                            opExp = new UnaryOperatorExpression(operatorType, rhs);
                        }
                        else
                        {
                            expect("& operator can only be followed by a variable expression");
                        }
                    }
                    else
                    {
                        expect("Expected *, + or - as unary operators but got "~to!(string)(operatorType));
                    }
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
                addRetExp(new StringExpression(lexer.getCurrentToken().getToken()));

                /* Get the next token */
                lexer.nextToken();
            }
            /* If we have a `[` (array index/access) */
            else if(symbol == SymbolType.OBRACKET)
            {
                // Pop off an expression which will be `indexTo`
                Expression indexTo = removeExp();
                gprintln("indexTo: "~indexTo.toString());

                /* Get the index expression */
                lexer.nextToken();
                Expression index = parseExpression();
                lexer.nextToken();
                gprintln("IndexExpr: "~index.toString());
                // gprintln(lexer.getCurrentToken());

                ArrayIndex arrayIndexExpr = new ArrayIndex(indexTo, index);
                addRetExp(arrayIndexExpr);
            }
            /* If it is an identifier */
            else if (symbol == SymbolType.IDENT_TYPE)
            {
                string identifier = lexer.getCurrentToken().getToken();

                lexer.nextToken();

                Expression toAdd;

                /* If the symbol is `(` then function call */
                if (getSymbolType(lexer.getCurrentToken()) == SymbolType.LBRACE)
                {
                    /* TODO: Implement function call parsing */
                    lexer.previousToken();
                    toAdd = parseFuncCall();
                }
                else
                {
                    /* TODO: Leave the token here */
                    /* TODO: Just leave it, yeah */
                    // expect("poes");
                    toAdd = new VariableExpression(identifier);

                    /**
                    * FIXME: To properly support function handles I think we are going to need a new type
                    * Well not here, this should technically be IdentExpression.
                    */
                }

                /* TODO: Change this later, for now we doing this */
                addRetExp(toAdd);
            }
            /* Detect if this expression is coming to an end, then return */
            else if (symbol == SymbolType.SEMICOLON || symbol == SymbolType.RBRACE ||
                    symbol == SymbolType.COMMA || symbol == SymbolType.ASSIGN ||
                    symbol == SymbolType.CBRACKET)
            {
                break;
            }
            /**
            * For ()
            */
            else if (symbol == SymbolType.LBRACE)
            {
                /* Consume the `(` */
                lexer.nextToken();

                /* Parse the inner expression till terminator */
                addRetExp(parseExpression());

                /* Consume the terminator */
                lexer.nextToken();
            }
            /**
            * `new` operator
            */
            else if(symbol == SymbolType.NEW)
            {
                /* Cosume the `new` */
                lexer.nextToken();

                /* Get the identifier */
                string identifier = lexer.getCurrentToken().getToken();
                lexer.nextToken();


                NewExpression toAdd;
                FunctionCall functionCallPart;

                /* If the symbol is `(` then function call */
                if (getSymbolType(lexer.getCurrentToken()) == SymbolType.LBRACE)
                {
                    /* TODO: Implement function call parsing */
                    lexer.previousToken();
                    functionCallPart = parseFuncCall();
                }
                /* If not an `(` */
                else
                {
                    /* Raise a syntax error */
                    expect(SymbolType.LBRACE, lexer.getCurrentToken());
                }

                /* Create a NewExpression with the associated FunctionCall */
                toAdd = new NewExpression(functionCallPart);

                /* Add the expression */
                addRetExp(toAdd);
            }
            /* TODO: New addition (UNTESTED, remove if problem causer) */
            else if(symbol == SymbolType.DOT)
            {
                /* Pop the previous expression */
                Expression previousExpression = removeExp();

                /* TODO: Get next expression */
                lexer.nextToken();
                Expression item = parseExpression();

                /* TODO: Construct accessor expression from both and addRetExp */

                BinaryOperatorExpression binOp = new BinaryOperatorExpression(SymbolType.DOT, previousExpression, item);

                addRetExp(binOp);
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

    

    // TODO: Update to `Statement` as this can return an ArrayAssignment now
    private Statement parseTypedDeclaration(bool wantsBody = true, bool allowVarDec = true, bool allowFuncDef = true, bool onlyType = false)
    {
        gprintln("parseTypedDeclaration(): Enter", DebugType.WARNING);


        /* Generated object */
        Statement generated;


        /* TODO: Save type */
        string type = lexer.getCurrentToken().getToken();
        string identifier;
        lexer.nextToken();

      

        /* Potential array index expressions (assignment) */
        // Think myArray[i][1] -> [`i`, `1`]
        Expression[] arrayIndexExprs;

        // We are currently 1 past the "type" (the identifier) so go back one
        ulong arrayAssignTokenBeginPos = lexer.getCursor()-1;

        /* Potential stack-array type size (declaration) */
        string potentialStackSize;

        /* Handling of pointer and array types */
        while(getSymbolType(lexer.getCurrentToken()) == SymbolType.STAR || getSymbolType(lexer.getCurrentToken()) == SymbolType.OBRACKET)
        {
            /* If we have `[` then expect a number and/or a `]` */
            if(getSymbolType(lexer.getCurrentToken()) == SymbolType.OBRACKET)
            {
                lexer.nextToken();
                SymbolType nextType = getSymbolType(lexer.getCurrentToken());
                

                /* Check if the next symbol is NOT a `]` */
                if(nextType != SymbolType.CBRACKET)
                {
                    

                    arrayIndexExprs ~= parseExpression();

                    /**
                     * If it is the case it is a number literal then save it
                     * anyways just for the case whereby we may be declaring
                     * a stack-array type
                     *
                     * TODO: Double check any error checking here which should be deferred to later
                     */
                    if(nextType == SymbolType.NUMBER_LITERAL)
                    {
                        // TODO: Ensure the returned thing is a number
                        // TODO: Ensure said number is non-negative
                        // TODO: May as well now start adding `]` as a seperator or stopper or something
                        IntegerLiteral stackArraySize = cast(IntegerLiteral)arrayIndexExprs[$-1];

                        // If the expression is an integer (which it should be)
                        if(stackArraySize)
                        {
                            gprintln("StackArraySize: "~stackArraySize.toString());
                            potentialStackSize = stackArraySize.getNumber();
                        }
                        // If not, then error
                        else
                        {
                            gprintln("Expected an integer as stack-array size but got iets ander", DebugType.ERROR);
                            // TODO: Rather throw a parsing error
                            assert(false);
                        }
                    }
                }

                

                expect(SymbolType.CBRACKET, lexer.getCurrentToken());
                type=type~"["~potentialStackSize~"]";
            }
            /* If we have `*` */
            else
            {
                type=type~"*";
            }
            
            lexer.nextToken();
        }

        /* If were requested to only find a type, then stop here and return it */
        if(onlyType)
        {
            /* Create a bogus TypedEntity for the sole purpose of returning the type */
            generated = new TypedEntity("BOGUS_NAME_STOP_SHORT_OF_IDENTIFIER_TYPE_FETCH", type);

            return generated;
        }

        /* If we are going to be assigning into an array (indexed) */
        bool arrayIndexing = false;


        /* If the current token is ASSIGN then array indexing is occuring */
        if(getSymbolType(lexer.getCurrentToken()) == SymbolType.ASSIGN)
        {
            // Then we are doing an array-indexed assignment
            arrayIndexing = true;
        }
        /* If we have an identifier the a declaration is occuring */
        else if(getSymbolType(lexer.getCurrentToken()) == SymbolType.IDENT_TYPE)
        {
            /* Expect an identifier (CAN NOT be dotted) */
            expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
            if(!isIdentifier_NoDot(lexer.getCurrentToken()))
            {
                expect("Identifier cannot be dotted");
            }
            identifier = lexer.getCurrentToken().getToken();

            lexer.nextToken();
            gprintln("ParseTypedDec: DecisionBtwn FuncDef/VarDef: " ~ lexer.getCurrentToken().getToken());
        }
        /* Anything else is an error */
        else
        {
            expect("Either a identity or an assignment symbol is expected");
        }


       

        /* Check if it is `(` (func dec) */
        SymbolType symbolType = getSymbolType(lexer.getCurrentToken());
        gprintln("ParseTypedDec: SymbolType=" ~ to!(string)(symbolType));
        if (symbolType == SymbolType.LBRACE)
        {
            // Only continue is function definitions are allowed
            if(allowFuncDef)
            {
                /* Will consume the `}` (or `;` if wantsBody-false) */
                funcDefPair pair = parseFuncDef(wantsBody);

                

                generated = new Function(identifier, type, pair.bodyStatements, pair.params);

                /**
                 * If this function definition has a body (i.e. `wantsBody == true`)
                 * and if the return type is non-void, THEN ensure we have a `ReturnStmt`
                 * (return statement)
                 */
                if(wantsBody && type != "void")
                {
                    /* Recurse down to find a `ReturnStmt` */
                    bool hasReturn = existsWithin(typeid(ReturnStmt), cast(Container)generated);

                    // Error if no return statement exists
                    if(!hasReturn)
                    {
                        expect("Function '"~identifier~"' declared with return type does not contain a return statement");
                    }
                }
                
                import std.stdio;
                writeln(to!(string)((cast(Function)generated).getVariables()));

                // Parent the parameters of the function to the Function
                parentToContainer(cast(Container)generated, cast(Statement[])pair.params);

                // Parent the statements that make up the function to the Function
                parentToContainer(cast(Container)generated, pair.bodyStatements);
            }
            else
            {
                expect("Function definitions not allowed");
            }
        }
        /* Check for semi-colon (var dec) */
        else if (symbolType == SymbolType.SEMICOLON)
        {
            // Only continue if variable declarations are allowed
            if(allowVarDec)
            {
                gprintln("Semi: "~to!(string)(lexer.getCurrentToken()));
                gprintln("Semi: "~to!(string)(lexer.getCurrentToken()));
                gprintln("ParseTypedDec: VariableDeclaration: (Type: " ~ type ~ ", Identifier: " ~ identifier ~ ")",
                        DebugType.WARNING);

                generated = new Variable(type, identifier);
            }
            else
            {
                expect("Variables declarations are not allowed.");
            }
        }
        /* Check for `=` (var dec) */
        else if (symbolType == SymbolType.ASSIGN && (arrayIndexing == false))
        {
            // Only continue if variable declarations are allowed
            if(allowVarDec)
            {
                // Only continue if assignments are allowed
                if(wantsBody)
                {
                    /* Consume the `=` token */
                    lexer.nextToken();

                    /* Now parse an expression */
                    Expression expression = parseExpression();

                    VariableAssignment varAssign = new VariableAssignment(expression);

                    gprintln("ParseTypedDec: VariableDeclarationWithAssingment: (Type: "
                            ~ type ~ ", Identifier: " ~ identifier ~ ")", DebugType.WARNING);
                    
                    Variable variable = new Variable(type, identifier);
                    variable.addAssignment(varAssign);

                    varAssign.setVariable(variable);

                    generated = variable;
                }
                else
                {
                    expect("Variable assignments+declarations are not allowed.");
                }
            }
            else
            {
                expect("Variables declarations are not allowed.");
            }
        }
        /* Check for `=` (array indexed assignment) */
        else if (symbolType == SymbolType.ASSIGN && (arrayIndexing == true))
        {
            // Set the token pointer back to the beginning
            lexer.setCursor(arrayAssignTokenBeginPos);
            gprintln("Looking at: "~to!(string)(lexer.getCurrentToken()));

            // TODO: Move all below code to the branch below that handles this case
            gprintln("We have an array assignment, here is the indexers: "~to!(string)(arrayIndexExprs), DebugType.WARNING);

            // Our identifier will be some weird malformed-looking `mrArray[][1]` (because os atck array size declarations no-number literal)
            // ... expressions don't make it in (we have arrayIndexExprs for that). Therefore what we must do is actually
            // strip the array bracket syntax away to get the name
            import std.string : indexOf;
            long firstBracket = indexOf(type, "[");
            assert(firstBracket > -1);
            identifier = type[0..firstBracket];
            gprintln("Then identifier is type actually: "~identifier);


            gprintln("We are still implenenting array assignments", DebugType.ERROR);

            ArrayIndex muhIndex = cast(ArrayIndex)parseExpression();
            gprintln("Expback: "~muhIndex.toString());

            /* Expect a `=` and consume it */
            gprintln(lexer.getCurrentToken());
            expect(SymbolType.ASSIGN, lexer.getCurrentToken());
            lexer.nextToken();

            /* Parse the expression being assigned followed by a semi-colon `;` */
            Expression expressionBeingAssigned = parseExpression();
            expect(SymbolType.SEMICOLON, lexer.getCurrentToken());

            // TODO: Get the expression after the `=`
            ArrayAssignment arrayAssignment = new ArrayAssignment(muhIndex, expressionBeingAssigned);
            gprintln("Created array assignment: "~arrayAssignment.toString());
            // assert(false);

            generated = arrayAssignment;
        }
        else
        {
            expect("Expected one of the following: (, ; or =");
        }

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
        lexer.nextToken();

        /* Get the class's name (CAN NOT be dotted) */
        expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
        if(!isIdentifier_NoDot(lexer.getCurrentToken()))
        {
            expect("Class name in declaration cannot be path");
        }
        string className = lexer.getCurrentToken().getToken();
        gprintln("parseClass(): Class name found '" ~ className ~ "'");
        lexer.nextToken();

        generated = new Clazz(className);

        string[] inheritList;

        /* TODO: If we have the inherit symbol `:` */
        if(getSymbolType(lexer.getCurrentToken()) == SymbolType.INHERIT_OPP)
        {
            /* TODO: Loop until `}` */

            /* Consume the inheritance operator `:` */
            lexer.nextToken();

            while(true)
            {
                /* Check if it is an identifier (may be dotted) */
                expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
                inheritList ~= lexer.getCurrentToken().getToken();
                lexer.nextToken();

                /* Check if we have ended with a `{` */
                if(getSymbolType(lexer.getCurrentToken()) == SymbolType.OCURLY)
                {
                    /* Exit */
                    break;
                }
                /* If we get a comma */
                else if(getSymbolType(lexer.getCurrentToken()) == SymbolType.COMMA)
                {
                    /* Consume */
                    lexer.nextToken();
                }
                /* Error out if we get anything else */
                else
                {
                    expect("Expected either { or ,");
                }
            }
        }








        /* TODO: Here we will do a while loop */
        expect(SymbolType.OCURLY, lexer.getCurrentToken());
        lexer.nextToken();

        Statement[] statements;

        while(true)
        {
            /* Get current token */
            SymbolType symbolType = getSymbolType(lexer.getCurrentToken());

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
            else if (isAccessor(lexer.getCurrentToken()))
            {
                structMember = parseAccessor();
            }
            /* If is is a modifier */
            else if(isModifier(lexer.getCurrentToken()))
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
        lexer.nextToken();

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

    private Statement parseDerefAssignment()
    {
        gprintln("parseDerefAssignment(): Enter", DebugType.WARNING);

        Statement statement;

        /* Consume the star `*` */
        lexer.nextToken();
        ulong derefCnt = 1;

        /* Check if there is another star */
        while(getSymbolType(lexer.getCurrentToken()) == SymbolType.STAR)
        {
            derefCnt+=1;
            lexer.nextToken();
        }

        /* Expect an expression */
        Expression pointerExpression = parseExpression();

        /* Expect an assignment operator */
        expect(SymbolType.ASSIGN, lexer.getCurrentToken());
        lexer.nextToken();

        /* Expect an expression */
        Expression assigmentExpression = parseExpression();

        /* Expect a semicolon */
        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        // FIXME: We should make a LHSPiinterAssignmentThing
        statement = new PointerDereferenceAssignment(pointerExpression, assigmentExpression, derefCnt);

        gprintln("parseDerefAssignment(): Leave", DebugType.WARNING);

        return statement;
    }

    // TODO: This ic currently dead code and ought to be used/implemented
    private Statement parseStatement(SymbolType terminatingSymbol = SymbolType.SEMICOLON)
    {
        gprintln("parseStatement(): Enter", DebugType.WARNING);

        /* Get the token */
        Token tok = lexer.getCurrentToken();
        SymbolType symbol = getSymbolType(tok);

        gprintln("parseStatement(): SymbolType=" ~ to!(string)(symbol));

        Statement statement;

        /* If it is a type */
        if(symbol == SymbolType.IDENT_TYPE)
        {
            /* Might be a function, might be a variable, or assignment */
            statement = parseName(terminatingSymbol);
        }
        /* If it is an accessor */
        else if(isAccessor(tok))
        {
            statement = parseAccessor();
        }
        /* If it is a modifier */
        else if(isModifier(tok))
        {
            statement = parseInitScope();
        }
        /* If it is a branch */
        else if(symbol == SymbolType.IF)
        {
            statement = parseIf();
        }
        /* If it is a while loop */
        else if(symbol == SymbolType.WHILE)
        {
            statement = parseWhile();
        }
        /* If it is a do-while loop */
        else if(symbol == SymbolType.DO)
        {
            statement = parseDoWhile();
        }
        /* If it is a for loop */
        else if(symbol == SymbolType.FOR)
        {
            statement = parseFor();
        }
        /* If it is a function call (further inspection needed) */
        else if(symbol == SymbolType.IDENT_TYPE)
        {
            /* Function calls can have dotted identifiers */
            parseFuncCall();
        }
        /* If it is the return keyword */
        //TODO: We should add a flag to prevent return being used in generla bodies? or wait we have a non parseBiody already
        else if(symbol == SymbolType.RETURN)
        {
            /* Parse the return statement */
            statement = parseReturn();
        }
        /* If it is a `discard` statement */
        else if(symbol == SymbolType.DISCARD)
        {
            /* Parse the discard statement */
            statement = parseDiscard();
        }
        /* If it is a dereference assigment (a `*`) */
        else if(symbol == SymbolType.STAR)
        {
            statement = parseDerefAssignment();
        }
        /* Error out */
        else
        {
            expect("parseStatement(): Unknown symbol: " ~ lexer.getCurrentToken().getToken());
        }

        gprintln("parseStatement(): Leave", DebugType.WARNING);

        return statement;
    }

    private FunctionCall parseFuncCall()
    {
        gprintln("parseFuncCall(): Enter", DebugType.WARNING);

        /* TODO: Save name */
        string functionName = lexer.getCurrentToken().getToken();

        Expression[] arguments;

        lexer.nextToken();

        /* Expect an opening brace `(` */
        expect(SymbolType.LBRACE, lexer.getCurrentToken());
        lexer.nextToken();

        /* If next token is RBRACE we don't expect arguments */
        if(getSymbolType(lexer.getCurrentToken()) == SymbolType.RBRACE)
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
                if(getSymbolType(lexer.getCurrentToken()) == SymbolType.RBRACE)
                {
                    break;
                }
                /* If comma expect more */
                else if(getSymbolType(lexer.getCurrentToken()) == SymbolType.COMMA)
                {
                    lexer.nextToken();
                    /* TODO: If rbrace after then error, so save boolean */
                }
                /* TODO: Add else, could have exited on `;` which is invalid closing */
                else
                {
                    expect("Function call closed on ;, invalid");
                }
            }
        }

       
        lexer.nextToken();

        gprintln("parseFuncCall(): Leave", DebugType.WARNING);

        return new FunctionCall(functionName, arguments);
    }

    private ExternStmt parseExtern()
    {
        ExternStmt externStmt;

        /* Consume the `extern` token */
        lexer.nextToken();

        /* Expect the next token to be either `efunc` or `evariable` */
        SymbolType externType = getSymbolType(lexer.getCurrentToken());
        lexer.nextToken();

        /* Pseudo-entity */
        Entity pseudoEntity;

        /* External function symbol */
        if(externType == SymbolType.EXTERN_EFUNC)
        {
            // TODO: (For one below)(we should also disallow somehow assignment) - evar

            // We now parse function definition but with `wantsBody` set to false
            // indicating no body should be allowed.
            pseudoEntity = cast(TypedEntity)parseTypedDeclaration(false, false, true);

            // TODO: Add a check for this cast (AND parse wise if it is evan possible)
            assert(pseudoEntity);
        }
        /* External variable symbol */
        else if(externType == SymbolType.EXTERN_EVAR)
        {
            // We now parse a variable declaration but with the `wantsBody` set to false
            // indicating no assignment should be allowed.
            pseudoEntity = cast(TypedEntity)parseTypedDeclaration(false, true, false);

            // TODO: Add a check for this cast (AND parse wise if it is evan possible)
            assert(pseudoEntity);
        }
        /* Anything else is invalid */
        else
        {
            expect("Expected either extern function (efunc) or extern variable (evar)");
        }

        /* Expect a semicolon to end it all and then consume it */
        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        externStmt = new ExternStmt(pseudoEntity, externType);

        /* Mark the Entity as external */
        pseudoEntity.makeExternal();

        return externStmt;
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

        /* Expect `module` and module name and consume them (and `;`) */
        expect(SymbolType.MODULE, lexer.getCurrentToken());
        lexer.nextToken();

        /* Module name may NOT be dotted (TODO: Maybe it should be yeah) */
        expect(SymbolType.IDENT_TYPE, lexer.getCurrentToken());
        string programName = lexer.getCurrentToken().getToken();
        lexer.nextToken();

        expect(SymbolType.SEMICOLON, lexer.getCurrentToken());
        lexer.nextToken();

        /* Initialize Module */
        modulle = new Module(programName);

        /* TODO: do `lexer.hasTokens()` check */
        /* TODO: We should add `lexer.hasTokens()` to the `lexer.nextToken()` */
        /* TODO: And too the `getCurrentTokem()` and throw an error when we have ran out rather */

        /* We can have an import or vardef or funcdef */
        while (lexer.hasTokens())
        {
            /* Get the token */
            Token tok = lexer.getCurrentToken();
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
            /* If it is an extern */
            else if(symbol == SymbolType.EXTERN)
            {
                ExternStmt externStatement = parseExtern();

                modulle.addStatement(externStatement);
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


version(unittest)
{
    import std.file;
    import std.stdio;
    import tlang.compiler.lexer.core;
    import tlang.compiler.lexer.kinds.basic : BasicLexer;
    import tlang.compiler.typecheck.core;
}

/**
 * Basic Module test case
 */
unittest
{
    string sourceCode = `
module myModule;
`;

    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
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
    string sourceCode = `
module myModule;

class myClass1
{
    class myClass1_1
    {
        int entity;
    }

    class myClass2
    {
        int inner;
    }
}

class myClass2
{
    int outer;
}
`;

    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
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
        *
        * Both should be variables
        */
        assert(myClass1_myClass2_5 != myClass2);

        Entity innerVariable = tc.getResolver().resolveBest(c_myClass1_myClass2_5, "inner");
        Entity outerVariable = tc.getResolver().resolveBest(c_myClass2, "outer");
        assert(innerVariable !is null);
        assert(outerVariable !is null);
        assert(cast(Variable)innerVariable);
        assert(cast(Variable)outerVariable);


        innerVariable = tc.getResolver().resolveBest(c_myClass2, "inner");
        outerVariable = tc.getResolver().resolveBest(c_myClass1_myClass2_5, "outer");
        assert(innerVariable is null);
        assert(outerVariable is null); 

        /**
        * myClass1_1.entity should exist
        *
        * 1. Resolve from myClass1.myClass2 relative position
        */
        Entity variableEntity = tc.getResolver().resolveBest(c_myClass1_myClass2_5, "myClass1_1.entity");
        assert(variableEntity);

        /* Should be a variable */
        assert(cast(Variable)variableEntity);
    }
    catch(TError)
    {
        assert(false);
    }
}

/**
 * Discard statement test case
 */
unittest
{
    string sourceCode = `
module parser_discard;

void function()
{
    discard function();
}
`;


    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be parser_discard */
        assert(cmp(modulle.getName(), "parser_discard")==0);
        TypeChecker tc = new TypeChecker(modulle);

        
        /* Find the function named `function` */
        Entity func = tc.getResolver().resolveBest(modulle, "function");
        assert(func);
        assert(cast(Function)func); // Ensure it is a Funciton

        /* Get the function's body */
        Container funcContainer = cast(Container)func;
        assert(funcContainer);
        Statement[] functionStatements = funcContainer.getStatements();
        assert(functionStatements.length == 1);

        /* First statement should be a discard */
        DiscardStatement discard = cast(DiscardStatement)functionStatements[0];
        assert(discard);
        
        /* The statement being discarded should be a function call */
        FunctionCall functionCall = cast(FunctionCall)discard.getExpression();
        assert(functionCall);
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 * Function definition test case
 */
unittest
{
    string sourceCode = `
module parser_function_def;

int myFunction(int i, int j)
{
    int k = i + j;

    return k+1;
}
`;


    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be parser_function_def */
        assert(cmp(modulle.getName(), "parser_function_def")==0);
        TypeChecker tc = new TypeChecker(modulle);

        
        /* Find the function named `myFunction` */
        Entity func = tc.getResolver().resolveBest(modulle, "myFunction");
        assert(func);
        assert(cast(Function)func); // Ensure it is a Funciton

        /* Get the function's body */
        Container funcContainer = cast(Container)func;
        assert(funcContainer);
        Statement[] functionStatements = funcContainer.getStatements();

        // Two parameters, 1 local and a return
        assert(functionStatements.length == 4);

        /* First statement should be a variable (param) */
        VariableParameter varPar1 = cast(VariableParameter)functionStatements[0];
        assert(varPar1);
        assert(cmp(varPar1.getName(), "i") == 0);

        /* Second statement should be a variable (param) */
        VariableParameter varPar2 = cast(VariableParameter)functionStatements[1];
        assert(varPar2);
        assert(cmp(varPar2.getName(), "j") == 0);

        /* ThirdFirst statement should be a variable (local) */
        Variable varLocal = cast(Variable)functionStatements[2];
        assert(varLocal);
        assert(cmp(varLocal.getName(), "k") == 0);

        /* Last statement should be a return */
        assert(cast(ReturnStmt)functionStatements[3]);
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 * While loop test case (nested)
 */
unittest
{
    string sourceCode = `
module parser_while;

void function()
{
    int i = 0;
    while(i)
    {
        int p = i;

        while(i)
        {
            int f;
        }
    }
}
`;


    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be parser_while */
        assert(cmp(modulle.getName(), "parser_while")==0);
        TypeChecker tc = new TypeChecker(modulle);

        
        /* Find the function named `function` */
        Entity func = tc.getResolver().resolveBest(modulle, "function");
        assert(func);
        assert(cast(Function)func); // Ensure it is a Funciton

        /* Get the function's body */
        Container funcContainer = cast(Container)func;
        assert(funcContainer);
        Statement[] functionStatements = funcContainer.getStatements();
        assert(functionStatements.length == 2);

        /* Find the while loop within the function's body */
        WhileLoop potentialWhileLoop;
        foreach(Statement curStatement; functionStatements)
        {
            potentialWhileLoop = cast(WhileLoop)curStatement;

            if(potentialWhileLoop)
            {
                break;
            }
        }

        /* This must pass if we found the while loop */
        assert(potentialWhileLoop);

        /* Grab the branch of the while loop */
        Branch whileBranch = potentialWhileLoop.getBranch();
        assert(whileBranch);

        /* Ensure that we have one statement in this branch's body and that it is a Variable and next is a while loop */
        Statement[] whileBranchStatements = whileBranch.getStatements();
        assert(whileBranchStatements.length == 2);
        assert(cast(Variable)whileBranchStatements[0]);
        assert(cast(WhileLoop)whileBranchStatements[1]);

        /* The inner while loop also has a similiar structure, only one variable */
        WhileLoop innerLoop = cast(WhileLoop)whileBranchStatements[1];
        Branch innerWhileBranch = innerLoop.getBranch();
        assert(innerWhileBranch);
        Statement[] innerWhileBranchStatements = innerWhileBranch.getStatements();
        assert(innerWhileBranchStatements.length == 1);
        assert(cast(Variable)innerWhileBranchStatements[0]);
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 *
 */
unittest
{
    string sourceCode = `
module simple_pointer;

int j;

void myFunc(int* ptr, int** ptrPtr, int*** ptrPtrPtr)
{

}

int** funcPtr()
{
    return 1;
}

int function(int* ptr)
{
    *ptr = 2+2;

    return 0;
}

int thing()
{
    int discardExpr = function(&j);
    int** l;

    return 0;
}
`;
    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be simple_pointer */
        assert(cmp(modulle.getName(), "simple_pointer")==0);
        TypeChecker tc = new TypeChecker(modulle);

        /* Find the function named `function` */
        Entity funcFunction = tc.getResolver().resolveBest(modulle, "function");
        assert(funcFunction);
        assert(cast(Function)funcFunction); // Ensure it is a Function

        /* Find the function named `thing` */
        Entity funcThing = tc.getResolver().resolveBest(modulle, "thing");
        assert(funcThing);
        assert(cast(Function)funcThing); // Ensure it is a Function

        /* Find the variable named `j` */
        Entity variableJ = tc.getResolver().resolveBest(modulle, "j");
        assert(variableJ);
        assert(cast(Variable)variableJ);


        /* Get the `function`'s body */
        Container funcFunctionContainer = cast(Container)funcFunction;
        assert(funcFunctionContainer);
        Statement[] funcFunctionStatements = funcFunctionContainer.getStatements();
        assert(funcFunctionStatements.length == 3); // Remember this includes the parameters

        /* Get the `thing`'s body */
        Container funcThingContainer = cast(Container)funcThing;
        assert(funcThingContainer);
        Statement[] funcThingStatements = funcThingContainer.getStatements();
        assert(funcThingStatements.length == 3);

        // TODO: Finish this
        // TODO: Add a check for the Statement types in the bodies, the arguments and the parameters
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 * Do-while loop tests (TODO: Add this)
 */

/**
 * For loop tests (TODO: FInish this)
 */
unittest
{
    string sourceCode = `
module parser_for;

void function()
{
    int i = 0;
    for(int idx = i; idx < i; idx=idx+1)
    {
        i = i + 1;

        for(int idxInner = idx; idxInner < idx; idxInner = idxInner +1)
        {

        }
    }
}
`;


    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be parser_for */
        assert(cmp(modulle.getName(), "parser_for")==0);
        TypeChecker tc = new TypeChecker(modulle);

        
        /* Find the function named `function` */
        Entity func = tc.getResolver().resolveBest(modulle, "function");
        assert(func);
        assert(cast(Function)func); // Ensure it is a Funciton

        /* Get the function's body */
        Container funcContainer = cast(Container)func;
        assert(funcContainer);
        Statement[] functionStatements = funcContainer.getStatements();
        assert(functionStatements.length == 2);

        /* First statement should be a variable declaration */
        assert(cast(Variable)functionStatements[0]);

        /* Next statement should be a for loop */
        ForLoop outerLoop = cast(ForLoop)functionStatements[1];
        assert(outerLoop);

        /* Get the body of the for-loop which should be [preRun, Branch] */
        Statement[] outerLoopBody = outerLoop.getStatements();
        assert(outerLoopBody.length == 2);

        /* We should have a preRun Statement */
        assert(outerLoop.hasPreRunStatement());

        /* The first should be the [preRun, ] which should be a Variable (declaration) */
        Variable preRunVarDec = cast(Variable)(outerLoopBody[0]);
        assert(preRunVarDec);

        /* Next up is the branch */
        Branch outerLoopBranch = cast(Branch)outerLoopBody[1];
        assert(outerLoopBranch);

        /* The branch should have a condition */
        Expression outerLoopBranchCondition = outerLoopBranch.getCondition();
        assert(outerLoopBranchCondition);

        /* The branch should have a body made up of [varAssStdAlone, forLoop, postIteration] */
        Statement[] outerLoopBranchBody = outerLoopBranch.getStatements();
        assert(outerLoopBranchBody.length == 3);

        /* Check for [varAssStdAlone, ] */
        VariableAssignmentStdAlone outerLoopBranchBodyStmt1 = cast(VariableAssignmentStdAlone)outerLoopBranchBody[0];
        assert(outerLoopBranchBodyStmt1);

        /* Check for [, forLoop, ] */
        ForLoop innerLoop = cast(ForLoop)outerLoopBranchBody[1];
        assert(innerLoop);

        /* Check for [, postIteration] */
        VariableAssignmentStdAlone outerLoopBranchBodyStmt3 = cast(VariableAssignmentStdAlone)outerLoopBranchBody[2];
        assert(outerLoopBranchBodyStmt3);

        /* Start examining the inner for-loop */
        Branch innerLoopBranch = innerLoop.getBranch();
        assert(innerLoopBranch);

        /* The branch should have a condition */
        Expression innerLoopBranchCondition = innerLoopBranch.getCondition();
        assert(innerLoopBranchCondition);

        /* The branch should have a body made up of [postIteration] */
        Statement[] innerLoopBranchBody = innerLoopBranch.getStatements();
        assert(innerLoopBranchBody.length == 1);
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 * If statement tests
 */
unittest
{
    string sourceCode = `
module parser_if;

void function()
{
    int i = 0;
    if(i)
    {
        int p = -i;
    }
    else if(i)
    {
        int p = 3+(i*9);
    }
    else if(i)
    {

    }
    else
    {

    }
}
`;


    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        /* Module name must be parser_if */
        assert(cmp(modulle.getName(), "parser_if")==0);
        TypeChecker tc = new TypeChecker(modulle);

        /* Find the function named `function` */
        Entity func = tc.getResolver().resolveBest(modulle, "function");
        assert(func);
        assert(cast(Function)func); // Ensure it is a Funciton

        /* Get the function's body */
        Container funcContainer = cast(Container)func;
        assert(funcContainer);
        Statement[] functionStatements = funcContainer.getStatements();
        assert(functionStatements.length == 2);

        /* Second statement is an if statemnet */
        IfStatement ifStatement = cast(IfStatement)functionStatements[1];
        assert(ifStatement);
        
        /* Extract the branches (should be 4) */
        Branch[] ifStatementBranches = ifStatement.getBranches();
        assert(ifStatementBranches.length == 4);

        /* First branch should have one statement which is a variable declaration */
        Statement[] firstBranchBody = ifStatementBranches[0].getStatements();
        assert(firstBranchBody.length == 1);
        assert(cast(Variable)firstBranchBody[0]);

        /* Second branch should have one statement which is a variable declaration */
        Statement[] secondBranchBody = ifStatementBranches[1].getStatements();
        assert(secondBranchBody.length == 1);
        assert(cast(Variable)secondBranchBody[0]);

        /* Third branch should have no statements */
        Statement[] thirdBranchBody = ifStatementBranches[2].getStatements();
        assert(thirdBranchBody.length == 0);

        /* Forth branch should have no statements */
        Statement[] fourthBranchBody = ifStatementBranches[3].getStatements();
        assert(fourthBranchBody.length == 0);

        // TODO: @Tristan Add this
    }
    catch(TError e)
    {
        assert(false);
    }
}

/**
 * Function test case
 *
 * Test: A function of a non-void return type
 * must have a return statement
 */
unittest
{
    string sourceCode = `
module myModule;

int wrongFunction()
{

}
`;

    LexerInterface currentLexer = new BasicLexer(sourceCode);
    try
    {
        (cast(BasicLexer)currentLexer).performLex();
        assert(true);
    }
    catch(LexerException e)
    {
        assert(false);
    }
    
    
    Parser parser = new Parser(currentLexer);
    
    try
    {
        Module modulle = parser.parse();

        assert(false);
    }
    // TODO: Make more specific (see https://deavmi.assigned.network/git/tlang/tlang/issues/147)
    catch(TError)
    {
        assert(true);
    }
}