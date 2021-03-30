module compiler.symbols;

import compiler.lexer : Token;
import std.conv : to;
import std.string : isNumeric, cmp;
import misc.utils;

/**
    * All allowed symbols
    * TODO: There should be a symbol class with sub-types
    */
public enum SymbolType
{
    LE_SYMBOL,
    IDENT_TYPE,
    NUMBER_LITERAL,
    CHARACTER_LITERAL,
    STRING_LITERAL,
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




/* TODO: Later build classes specific to symbol */
public bool isType(string tokenStr)
{
    return cmp(tokenStr, "byte") == 0 || cmp(tokenStr, "ubyte") == 0
        || cmp(tokenStr, "short") == 0 || cmp(tokenStr, "ushort") == 0
        || cmp(tokenStr, "int") == 0 || cmp(tokenStr, "uint") == 0 || cmp(tokenStr,
                "long") == 0 || cmp(tokenStr, "ulong") == 0 || cmp(tokenStr, "void") == 0;
}

public bool isPathIdentifier(string token)
{
    /* This is used to prevent the first character from not being number */
    bool isFirstRun = true;

    /* Whether we found a dot or not */
    bool isDot;

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
            /* Check for dot */
            if(character == '.')
            {
                isDot = true;
            }
            else if(isCharacterAlpha(character) || character == '_' || isCharacterNumber(character))
            {

            }
            else
            {
                return false;
            }
        }
    }

    if(token.length)
    {
        if(token[token.length-1] == '.')
        {
            return false;
        }
    }

    return isDot;
}

public bool isIdentifier(string token)
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

public bool isIdentifier_NoDot(Token tokenIn)
{
    /* Make sure it isn't any other type of symbol */
    if(getSymbolType(tokenIn) == SymbolType.IDENT_TYPE)
    {
        return isIdentifier(tokenIn.getToken());
    }
    else
    {
        return false;
    }
}

public bool isIdentifier_Dot(Token tokenIn)
{
    /* Make sure it isn't any other type of symbol */
    if(getSymbolType(tokenIn) == SymbolType.IDENT_TYPE)
    {
        return isPathIdentifier(tokenIn.getToken()) || isIdentifier(tokenIn.getToken());
    }
    else
    {
        return false;
    }
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
    /* An identifier/type  (of some sorts) - further inspection in parser is needed */
    else if(isPathIdentifier(token) || isIdentifier(token))
    {
        return SymbolType.IDENT_TYPE;
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

    public static StatementType[] getAllOf(StatementType)(StatementType, Statement[] statements)
    {
        StatementType[] statementsMatched;

        foreach(Statement statement; statements)
        {
            /* TODO: Remove null, this is for unimpemented */
            if(statement !is null && cast(StatementType)statement)
            {
                statementsMatched ~= cast(StatementType)statement;
            }
        }

        return statementsMatched;
    }

    public Variable[] getGlobals()
    {
        Variable[] variables;

        foreach(Statement statement; statements)
        {
            if(typeid(statement) == typeid(Variable))
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    public Statement[] getStatements()
    {
        return statements;
    }
}

public class Statement
{
    private Container container;

    public final void parentTo(Container container)
    {
        this.container = container;
    }
}

public enum AccessorType
{
    PUBLIC, PRIVATE, PROTECTED, UNKNOWN
}

public enum FunctionType
{
    STATIC, VIRTUAL
}

/* Declared variables, defined classes and fucntions */
public class Entity : Statement
{
    /* Accesor type */
    private AccessorType accessorType = AccessorType.PUBLIC;

    /* Function/Modifier type */
    private FunctionType functionType;

    /* Name of the entity (class's name, function's name, variable's name) */
    private string name;

    this(string name)
    {
        this.name = name;
    }

    public void setAccessorType(AccessorType accessorType)
    {
        this.accessorType = accessorType;
    }

    public AccessorType getAccessorType()
    {
        return accessorType;
    }

    public void setModifierType(FunctionType functionType)
    {
        this.functionType = functionType;
    }

    public FunctionType getModifierType()
    {
        return functionType;
    }

    public string getName()
    {
        return name;
    }
}

/* TODO: DO we need intermediary class, TypedEntity */
public class TypedEntity : Entity
{
    private string type;

    /* TODO: Return type/variable type in here (do what we did for ENtity with `name/identifier`) */
    this(string name, string type)
    {
        super(name);
        this.type = type;
    }

    public string getType()
    {
        return type;
    }
}

public class Container : Entity
{
    private Statement[] statements;

    this(string name)
    {
        super(name);
    }

    public void addStatement(Statement statement)
    {
        this.statements ~= statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.statements ~= statements;
    }

    public Statement[] getStatements()
    {
        return statements;
    }
}

public class Module : Container
{
    this(string moduleName)
    {
        super(moduleName);
    }
}

public class Clazz : Container
{
    private string parentClass;
    private string[] interfaces;

    this(string name)
    {
        super(name);
    }

    /**
    * Checks all added Statement[]s and makes sure they
    * are either of type Variable, Function or Class
    */
    public bool isFine()
    {
        foreach(Statement statement; statements)
        {
            if(typeid(statement) != typeid(Variable) &&
                typeid(statement) != typeid(Function) &&
                typeid(statement) != typeid(Clazz))
            {
                return false;
            }
        }
        
        return true;
    }

    public override string toString()
    {
        return "Class (Name: "~name~", Parent: "~parentClass~", Interfaces: "~to!(string)(interfaces)~")";
    }
    
}

public class ArgumentList
{

}

public class Function : TypedEntity
{
    private Variable[] params;
    private Statement[] bodyStatements;

    this(string name, string returnType, Statement[] bodyStatements, Variable[] args)
    {
        super(name, returnType);
        this.bodyStatements = bodyStatements;
        this.params = args;
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

            if(statement !is null && cast(Variable)statement)
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    public override string toString()
    {
        string argTypes;

        for(ulong i = 0; i < params.length; i++)
        {
            Variable variable = params[i];

            if(i == params.length-1)
            {
                argTypes ~= variable.getType();
            }
            else
            {
                argTypes ~= variable.getType() ~ ", ";
            }
        }
        
        return "Function (Name: "~name~", ReturnType: "~type~", Args: "~argTypes~")";
    }
}

public class Variable : TypedEntity
{
    /* TODO: Just make this an Expression */
    private VariableAssignment assignment;

    this(string type, string identifier)
    {
        super(identifier, type);
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
        return "Variable (Ident: "~name~", Type: "~type~")";
    }

    /* Code gen */
}

public class Expression : Statement
{
    import compiler.typecheck.core;
    /* TODO: Takes in symbol table? */
    public string evaluateType(TypeChecker typechecker, Container c)
    {
        /* TODO: Go through here evaluating the type */

        return null;
    }

    this()
    {

    }

    /* TODO: Evalute this expression's type */
}



/* TODO: Look into arrays later */
public class StringExpression : Expression
{
    private string ztring;

    this(string ztring)
    {
        this.ztring = ztring;
    }
}

public class OperatorExpression : Expression
{
    /* Operator */
    private SymbolType operator;

    this(SymbolType operator)
    {
        this.operator = operator;
    }
}

public class UnaryOperatorExpression : OperatorExpression
{
    private Expression exp;

    this(SymbolType operator, Expression exp)
    {
        super(operator);
        this.exp = exp;
    }
}

public class BinaryOperatorExpression : OperatorExpression
{
    /* TODO: Take in operator */
    this(SymbolType operator, Expression lhs, Expression rhs)
    {
        super(operator);
    }
}

public class NumberLiteral : Expression
{
    private string numberLiteral;

    /* TODO: Take in info like tyoe */
    this(string numberLiteral)
    {
        this.numberLiteral = numberLiteral;
    }
}

public class VariableAssignment
{
    private Expression expression;

    this(Expression expression)
    {
        this.expression = expression;
    }

    public Expression getExpression()
    {
        return expression;
    }
}

public class IdentExpression : Expression
{
    /* name */
    private string name;

    this(string name)
    {
        this.name = name;
    }

    public string getName()
    {
        return name;
    }
}

public class VariableExpression : IdentExpression
{

    this(string identifier)
    {
        super(identifier);
    }

    import compiler.typecheck.core;
    public override string evaluateType(TypeChecker typeChecker, Container c)
    {
        string type;


        /**
        * Check to see if the Entity exists (somewhere)
        * in the source file
        */
        Entity entity = typeChecker.getEntity(c, getName());
        if(entity)
        {
            /**
            * Check if the Variable being referenced has been marked by
            * the type checker (declared and my now be accessed)
            */
            if(typeChecker.isMarkedEntity(entity))
            {
                /* TODO: DO TYPE HCEKC, MAKE SURE IT iS A VAR */
                return (cast(Variable)entity).getType();
            }
            else
            {
                return null;
            }
        }
        else
        {
            return null;
        }
    }
}

public class Call : IdentExpression
{
    this(string ident)
    {
        super(ident);
    }
}

public final class FunctionCall : Call
{
    

    /* Argument list */
    private Expression[] arguments;

    this(string functionName, Expression[] arguments)
    {
        super(functionName);
        this.arguments = arguments;
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
    assert(symbol == SymbolType.IDENT_TYPE);

    symbol = getSymbolType(new Token("2_2ff", 0, 0));
    assert(symbol != SymbolType.IDENT_TYPE);
}


/* Test: Identifier type detection */
unittest
{
    assert(isPathIdentifier("hello.e.e"));
    assert(!isPathIdentifier("hello"));
    assert(!isIdentifier("hello.e.e"));
    assert(isIdentifier("hello"));
    
    /* TODO: Add support for the below in lexer */
    assert(isPathIdentifier("hello._a.e"));
    assert(isPathIdentifier("hello._2._e"));
    
    
}
