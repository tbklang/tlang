module compiler.symbols;

import compiler.lexer : Token;
import std.conv : to;
import std.string : isNumeric, cmp;

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
    TYPE,
    SEMICOLON,
    LBRACE,
    RBRACE,
    ASSIGN,
    COMMA,
    OCURLY,
    CCURLY,
    MODULE,
    IF,
    ELSE,
    WHILE,
    CLASS,
    INHERIT_OPP,
    TILDE,
    FOR,
    SUPER,
    THIS,
    SWITCH,
    RETURN,
    PUBLIC,
    PRIVATE,
    PROTECTED,
    STATIC,
    CASE,
    GOTO,
    DO,
    DELETE,
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
public bool isType(string tokenStr)
{
    return cmp(tokenStr, "byte") == 0 || cmp(tokenStr, "ubyte") == 0
        || cmp(tokenStr, "short") == 0 || cmp(tokenStr, "ushort") == 0
        || cmp(tokenStr, "int") == 0 || cmp(tokenStr, "uint") == 0 || cmp(tokenStr,
                "long") == 0 || cmp(tokenStr, "ulong") == 0 || cmp(tokenStr, "void") == 0;
}

/**
* Checks if the given character is a letter
*/
private bool isCharacterAlpha(char character)
{
    return (character >= 65 && character <= 90) || (character >= 97 && character <= 122);
}

/**
* Checks if the given character is a number
*/
private bool isCharacterNumber(char character)
{
    return (character >= 48 && character <= 57);
}

private bool isIdentifier(string token)
{
    /* This is used to prevent the first character from not being number */
    bool isFirstRun = true;

    foreach (char character; token)
    {
        if(isFirstRun)
        {
            /* Only allow underscore of letter */
            if(isCharacterAlpha(character) || character == '_')
            {

            }
            else
            {
                return false;
            }

            isFirstRun = false;
        }
        else
        {
            if(isCharacterAlpha(character) || character == '_' || isCharacterNumber(character))
            {

            }
            else
            {
                return false;
            }
        }
    }

    return true;
}

public bool isAccessor(Token token)
{
    return getSymbolType(token) == SymbolType.PUBLIC ||
            getSymbolType(token) == SymbolType.PRIVATE ||
            getSymbolType(token) == SymbolType.PROTECTED;
}

public SymbolType getSymbolType(Token tokenIn)
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
    /* `if` */
    else if(cmp(token, "if") == 0)
    {
        return SymbolType.IF;
    }
    /* `else` */
    else if(cmp(token, "else") == 0)
    {
        return SymbolType.ELSE;
    }
    /* `while` */
    else if(cmp(token, "while") == 0)
    {
        return SymbolType.WHILE;
    }
    /* class keyword */
    else if(cmp(token, "class") == 0)
    {
        return SymbolType.CLASS;
    }
    /* static keyword */
    else if(cmp(token, "static") == 0)
    {
        return SymbolType.STATIC;
    }
    /* private keyword */
    else if(cmp(token, "private") == 0)
    {
        return SymbolType.PRIVATE;
    }
    /* public keyword */
    else if(cmp(token, "public") == 0)
    {
        return SymbolType.PUBLIC;
    }
    /* protected keyword */
    else if(cmp(token, "protected") == 0)
    {
        return SymbolType.PROTECTED;
    }
    /* return keyword */
    else if(cmp(token, "return") == 0)
    {
        return SymbolType.RETURN;
    }
    /* switch keyword */
    else if(cmp(token, "switch") == 0)
    {
        return SymbolType.SWITCH;
    }
    /* this keyword */
    else if(cmp(token, "this") == 0)
    {
        return SymbolType.THIS;
    }
    /* super keyword */
    else if(cmp(token, "super") == 0)
    {
        return SymbolType.SUPER;
    }
    /* for keyword */
    else if(cmp(token, "for") == 0)
    {
        return SymbolType.FOR;
    }
    /* case keyword */
    else if(cmp(token, "case") == 0)
    {
        return SymbolType.CASE;
    }
    /* goto keyword */
    else if(cmp(token, "goto") == 0)
    {
        return SymbolType.GOTO;
    }
    /* do keyword */
    else if(cmp(token, "do") == 0)
    {
        return SymbolType.DO;
    }
    /* delete keyword */
    else if(cmp(token, "delete") == 0)
    {
        return SymbolType.DELETE;
    }
    /* module keyword */
    else if(cmp(token, "module") == 0)
    {
        return SymbolType.MODULE;
    }
    /* Identifier check (TODO: Track vars) */
    else if (isIdentifier(token))
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
    /* Inheritance operator check */
    else if (token[0] == ':')
    {
        return SymbolType.INHERIT_OPP;
    }
    /* Tilde operator check */
    else if (token[0] == '~')
    {
        return SymbolType.TILDE;
    }
    
    
    
    

    return SymbolType.UNKNOWN;
}

public bool isMathOp(Token token)
{
    string tokenStr = token.getToken();

    return tokenStr[0] == '+' || tokenStr[0] == '-' ||
            tokenStr[0] == '*' || tokenStr[0] == '/';
}


/**
* TODO: Implement the blow and use them
*
* These are just to use for keeping track of what
* valid identifiers are.
*
* Actually it might be, yeah it will
*/

public class Program
{
    private string moduleName;
    private Program[] importedModules;

    private Statement[] statements;

    this(string moduleName)
    {
        this.moduleName = moduleName;
    }

    public void addStatement(Statement statement)
    {
        statements ~= statement;
    }

    public Variable[] getGlobals()
    {
        Variable[] variables;

        // foreach()

        return variables;
    }
}

public class Statement {}

public class TypedEntity : Statement {}


public class Clazz : Statement
{
    private string name;

    private Variable[] fields;
    private Function[] methods;

    this(string name)
    {
        this.name = name;
    }

    public void addField(Variable field)
    {
        fields ~= field;
    }

    public void addMethod(Function method)
    {
        methods ~= method;
    }

    
}

public class ArgumentList
{

}

public class Function : TypedEntity
{
    private string name;
    private ArgumentList[] params;
    private Statement[] bodyStatements;

    this(string name, string returnType, Statement[] bodyStatements, ArgumentList[] args)
    {
        this.name = name;
        this.bodyStatements = bodyStatements;

    }

    /**
    * This will sift through all the `Statement[]`'s in held
    * within this Function and will find those which are Variable
    */
    public Variable[] getVariables()
    {
        Variable[] variables;

        foreach(Statement statement; bodyStatements)
        {
            if(typeid(statement) == typeid(Variable))
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }
}

public class Variable : TypedEntity
{
    private string type;
    private string identifier;

    private VariableAssignment assignment;

    this(string type, string identifier)
    {
        this.type = type;
        this.identifier = identifier;
    }

    public void addAssignment(VariableAssignment assignment)
    {
        this.assignment = assignment;
    }

    public VariableAssignment getAssignment()
    {
        return assignment;
    }

    public override string toString()
    {
        return "Variable (Ident: "~identifier~", Type: "~type~")";
    }

    /* Code gen */
}

public class Expression : Statement
{
    this(Expression[] expressions)
    {

    }
}

public class VariableAssignment
{
    private Expression expression;

    this(Expression)
    {

    }
}



/* Test: Character literal */
unittest
{
    SymbolType symbol = getSymbolType(new Token("'c'", 0, 0));
    assert(symbol == SymbolType.CHARACTER_LITERAL);
}

/* Test: String literals */
unittest
{
    SymbolType symbol = getSymbolType(new Token("\"hello\"", 0, 0));
    assert(symbol == SymbolType.STRING_LITERAL);
}

/* Test: Number literals */
unittest
{
    SymbolType symbol = getSymbolType(new Token("2121", 0, 0));
    assert(symbol == SymbolType.NUMBER_LITERAL);

    symbol = getSymbolType(new Token("2121a", 0, 0));
    assert(symbol != SymbolType.NUMBER_LITERAL);
}

/* Test: Identifer tests */
unittest
{
    SymbolType symbol = getSymbolType(new Token("_yolo2", 0, 0));
    assert(symbol == SymbolType.IDENTIFIER);

    symbol = getSymbolType(new Token("2_2ff", 0, 0));
    assert(symbol != SymbolType.IDENTIFIER);
}

