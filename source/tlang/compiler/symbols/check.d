module compiler.symbols.check;

import compiler.lexer : Token;
import std.conv : to;
import std.string : isNumeric, cmp;
import misc.utils;
import gogga;

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
    NEW,
    IF,
    ELSE,
    DISCARD,
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
    DOT,
    DELETE,
    STRUCT,
    SUB,
    ADD,
    DIVIDE,
    STAR,
    AMPERSAND,
    EQUALS,
    GREATER_THAN,
    SMALLER_THAN,
    GREATER_THAN_OR_EQUALS,
    SMALLER_THAN_OR_EQUALS,
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

public bool isModifier(Token token)
{
    return getSymbolType(token) == SymbolType.STATIC;
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
    /* `struct` */
    else if(cmp(token, "struct") == 0)
    {
        return SymbolType.STRUCT;
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
    /* new keyword */
    else if(cmp(token, "new") == 0)
    {
        return SymbolType.NEW;
    }
    /* discard keyword */
    else if(cmp(token, "discard") == 0)
    {
        return SymbolType.DISCARD;
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
    /* Equality `==` check */
    else if(cmp(token, "==") == 0)
    {
        return SymbolType.EQUALS;
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
    /* Dot operator check */
    else if (token[0] == '.')
    {
        return SymbolType.DOT;
    }
    /* Add `+` operator check  */
    else if(token[0] == '+')
    {
        return SymbolType.ADD;
    }
    /* Subtraction `-` operator check  */
    else if(token[0] == '-')
    {
        return SymbolType.SUB;
    }
    /* Multiply `*` operator check  */
    else if(token[0] == '*')
    {
        return SymbolType.STAR;
    }
    /* Divide `/` operator check  */
    else if(token[0] == '/')
    {
        return SymbolType.DIVIDE;
    }
    /* Ampersand `&` operator check  */
    else if(token[0] == '&')
    {
        return SymbolType.AMPERSAND;
    }
    /* Greater than `>` operator check */
    else if(token[0] == '>')
    {
        return SymbolType.GREATER_THAN;
    }
    /* Smaller than `<` operator check */
    else if(token[0] == '<')
    {
        return SymbolType.SMALLER_THAN;
    }
    /* Greater than or equals to `>=` operator check */
    else if(cmp(">=", token) == 0)
    {
        return SymbolType.GREATER_THAN_OR_EQUALS;
    }
    /* Smaller than or equals to `<=` operator check */
    else if(cmp("<=", token) == 0)
    {
        return SymbolType.SMALLER_THAN_OR_EQUALS;
    }
    

    return SymbolType.UNKNOWN;
}

public bool isMathOp(Token token)
{
    string tokenStr = token.getToken();

    return tokenStr[0] == '+' || tokenStr[0] == '-' ||
            tokenStr[0] == '*' || tokenStr[0] == '/';
}

public bool isBinaryOp(Token token)
{
    string tokenStr = token.getToken();

    return tokenStr[0] == '&' ||  cmp("&&", tokenStr) == 0 ||
            tokenStr[0] == '|' || cmp("||", tokenStr) == 0 ||
            tokenStr[0] == '^' || tokenStr[0] == '~'       ||
            tokenStr[0] == '<' || tokenStr[0] == '>'       ||
            cmp(">=", tokenStr) == 0 || cmp("<=", tokenStr) == 0 ||
            cmp("==", tokenStr) == 0;
}

/** 
 * Returns the corresponding character for a given SymbolType
 *
 * For example <code>SymbolType.ADD</code> returns +
 *
 * Params:
 *   symbolIn = The symbol to lookup against
 * Returns: The corresponding character
 *
 */
public string getCharacter(SymbolType symbolIn)
{
    if(symbolIn == SymbolType.ADD)
    {
        return "+";
    }
    else if(symbolIn == SymbolType.STAR)
    {
        return "*";
    }
    else if(symbolIn == SymbolType.SUB)
    {
        return "-";
    }
    else if(symbolIn == SymbolType.DIVIDE)
    {
        return "/";
    }
    else if(symbolIn == SymbolType.OCURLY)
    {
        return "{";
    }
    else if(symbolIn == SymbolType.CCURLY)
    {
        return "}";
    }
    else
    {
        gprintln("getCharacter: No back-mapping for "~to!(string)(symbolIn), DebugType.ERROR);
        assert(false);
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
