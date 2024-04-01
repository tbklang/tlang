/** 
 * Token-to-symbol mappings (and vice-versa),
 * facilities for performing tests on what sort
 * of tokens are of certain classes (operators, etc.)
 * and detection of different types of identifiers
 */
module tlang.compiler.symbols.check;

import tlang.compiler.lexer.core.tokens : Token;
import std.conv : to;
import std.string : isNumeric, cmp;
import std.algorithm.searching : canFind;
import misc.utils;
import gogga;

/**
 * All allowed symbols
 */
public enum SymbolType
{
    /**
     * Default symbol (TODO: idk why this exists)
     */
    LE_SYMBOL,

    /**
     * Any sort of identifier
     *
     * Must start with a letter,
     * can contain numbers and
     * may contain periods.
     *
     * It may also contain underscores.
     */
    IDENT_TYPE,

    /**
     * Any sort of number, this can
     * be `8` or `8.5`
     */
    NUMBER_LITERAL,

    /**
     * A character constant like `'a'`
     */
    CHARACTER_LITERAL,

    /**
     * A string constant like `"FELLA"`
     */
    STRING_LITERAL,

    /**
     * Semicolon `;`
     */
    SEMICOLON,

    /**
     * Left smooth brace $(LPAREN)
     */
    LBRACE,

    /**
     * Right smooth brace $(RPAREN)
     */
    RBRACE,

    /**
     * Assigmment symbol `=`
     */
    ASSIGN,

    /**
     * Comma `,`
     */
    COMMA,

    /**
     * Left curly brace `{`
     */
    OCURLY,

    /**
     * Right curly brace `}`
     */
    CCURLY,

    /**
     * Module keyword `module`
     */
    MODULE,

    /**
     * New keyword `new`
     */
    NEW,

    /**
     * If keyword `if`
     */
    IF,

    /**
     * Else keyword `else`
     */
    ELSE,

    /**
     * Discard keyword `discard`
     */
    DISCARD,

    /**
     * While keyword `while`
     */
    WHILE,

    /**
     * Class keyword `class`
     */
    CLASS,

    /**
     * Inherit keyword `:`
     */
    INHERIT_OPP,

    /**
     * Tilde `~`
     */
    TILDE,

    /**
     * For keyword `for`
     */
    FOR,

    /**
     * Super keyword `super`
     */
    SUPER,

    /**
     * This keyword `this`
     */
    THIS,

    /**
     * Switch keyword `switch`
     */
    SWITCH,

    /**
     * Return keyword `return`
     */
    RETURN,

    /**
     * Public keyword `public`
     */
    PUBLIC,

    /**
     * Private keyword `private`
     */
    PRIVATE,

    /**
     * Protected keyword `protected`
     */
    PROTECTED,

    /**
     * Static keyword `static`
     */
    STATIC,

    /**
     * Case keyword `case`
     */
    CASE,

    /**
     * Goto keyword `goto`
     */
    GOTO,

    /**
     * Do keyword `do`
     */
    DO,

    /**
     * Dot operator `.`
     */
    DOT,

    /**
     * Delete keyword `delete`
     */
    DELETE,

    /**
     * Struct keyword `struct`
     */
    STRUCT,

    /**
     * Subtraction operator `-`
     */
    SUB,

    /**
     * Addition operator `+`
     */
    ADD,

    /**
     * Division operator `/`
     */
    DIVIDE,

    /**
     * Star operator `*`
     */
    STAR,

    /**
     * Ampersand (reffer) operator `&`
     */
    AMPERSAND,

    /**
     * Equality operator `==`
     */
    EQUALS,

    /**
     * Greater than operator `>`
     */
    GREATER_THAN,

    /**
     * Smaller than operator `<`
     */
    SMALLER_THAN,

    /**
     * Greater than or equals to operator `>=`
     */
    GREATER_THAN_OR_EQUALS,

    /**
     * Smaller than or equals to operator `<=`
     */
    SMALLER_THAN_OR_EQUALS,

    /**
     * Opening bracket `[`
     */
    OBRACKET,

    /**
     * Closing bracket `]`
     */
    CBRACKET,

    /**
     * Cast keyword `cast`
     */
    CAST,

    /**
     * Extern keyword `extern`
     */
    EXTERN,

    /**
     * Extern-function keyword `efunc`
     */
    EXTERN_EFUNC,

    /**
     * Extern-variable keyword `evar`
     */
    EXTERN_EVAR,

    /** 
     * `generic`
     */
    GENERIC_TYPE_DECLARE,

    /**
     * Multi-line comment (frwd-slash-star)
     */
    MULTI_LINE_COMMENT,

    /**
     * Singleiline comment (frwd-slash-slash)
     */
    SINGLE_LINE_COMMENT,

    /** 
     * Unknown symbol
     */
    UNKNOWN
}

/* TODO: Later build classes specific to symbol */
/* TODO: Check if below is even used */
/** 
 * Checks if the given token string is that of
 * a built-in type
 *
 * Params:
 *   tokenStr = the string to check
 * Returns: `true` if one of the built-in types,
 * `false` otherwise
 */
public bool isType(string tokenStr)
{
    return cmp(tokenStr, "byte") == 0 || cmp(tokenStr, "ubyte") == 0
        || cmp(tokenStr, "short") == 0 || cmp(tokenStr, "ushort") == 0
        || cmp(tokenStr, "int") == 0 || cmp(tokenStr, "uint") == 0 || cmp(tokenStr,
                "long") == 0 || cmp(tokenStr, "ulong") == 0 || cmp(tokenStr, "void") == 0;
}

/** 
 * Checks if the given token string is a path
 * identifier. This means that it is something
 * which contains dots inbetween it like `a.b`
 * but does not appear as a floating point literal
 * such as `7.5`. It may also contain udnerscores `_`.
 *
 * Params:
 *   token = the token string to check
 * Returns: `true` if it is a path identifier,
 * `false` otherwise
 */
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

/** 
 * Checks if the given token string is an identifier
 * which means it can contains letters and umbers
 * but MUST start with a letter. It may also
 * contain udnerscores `_`.
 *
 * Params:
 *   token = the token string to check
 * Returns: `true` if an identifier, `flase`
 * otherwise
 */
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

/** 
 * Checks if the given `Token` is an accessor
 *
 * Params:
 *   token = the `Token` to check
 * Returns: `true` if so, `false` otherwise
 */
public bool isAccessor(Token token)
{
    return getSymbolType(token) == SymbolType.PUBLIC ||
            getSymbolType(token) == SymbolType.PRIVATE ||
            getSymbolType(token) == SymbolType.PROTECTED;
}

/** 
 * Checks if the given `Token` is a modifier
 *
 * Params:
 *   token = the `Token` to check
 * Returns: `true` if so, `false` otherwise
 */
public bool isModifier(Token token)
{
    return getSymbolType(token) == SymbolType.STATIC;
}

/** 
 * Checks if the given `Token` is a normal
 * identifier (with no dots/periods)
 *
 * Params:
 *   tokenIn = the `Token` to test
 * Returns: `true` if so, `false` otherwise
 */
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

/** 
 * Checks if the given `Token` is a dotted-identifier
 * meaning it contains `.`/periods in it - a so-called
 * path identifier.
 *
 * Params:
 *   tokenIn = the `Token` to test
 * Returns: `true` if so, `false` otherwise
 */
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

/** 
 * Checks if the given token string
 * as a numeric literal. It has support
 * for checking if it has a size specifier
 * as well.
 *
 * Params:
 *   token = the string token to check
 * Returns: `true` if it is a numeric literal,
 * `false` otherwise
 */
private bool isNumericLiteral(string token)
{
    if(canFind(token, "UL") || canFind(token, "UI"))
    {
        return isNumeric(token[0..$-2]);
    }
    else if(canFind(token, "L") || canFind(token, "I"))
    {
        return isNumeric(token[0..$-1]);
    }
    else
    {
        // TODO: Check if we would even get here in terms of what the lexer
        // ... would be able to rpoduce.
        // We would get ehre with `1` for example, however check if `1A`
        // would even be possible (if not then remove isNumeric below, else keep)
        return isNumeric(token);
    }
}

/** 
 * Maps a given `Token` to its `SymbolType` such
 * that you can determine the type of symbol it
 * is.
 *
 * Params:
 *   tokenIn = the `Token` to check
 * Returns: the `SymbolType` of this token, if
 * unrecgnizable then `SymbolType.UNKNOWN` is
 * returned
 */
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
    // FIXME: Add support for 2UI and 2I (isNumeric checks via D's logic)
    else if (isNumericLiteral(token))
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
    /* efunc keyword */
    else if(cmp(token, "efunc") == 0)
    {
        return SymbolType.EXTERN_EFUNC;
    }
    /* evar keyword */
    else if(cmp(token, "evar") == 0)
    {
        return SymbolType.EXTERN_EVAR;
    }
    /* extern keyword */
    else if(cmp(token, "extern") == 0)
    {
        return SymbolType.EXTERN;
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
    /* cast keyword */
    else if(cmp(token, "cast") == 0)
    {
        return SymbolType.CAST;
    }
    /* discard keyword */
    else if(cmp(token, "discard") == 0)
    {
        return SymbolType.DISCARD;
    }
    /* generic keyword */
    else if(cmp(token, "generic") == 0)
    {
        return SymbolType.GENERIC_TYPE_DECLARE;
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
    /* Left-bracket checl */
    else if(token[0] == '[')
    {
        return SymbolType.OBRACKET;
    }
    /* Right-bracket check */
    else if(token[0] == ']')
    {
        return SymbolType.CBRACKET;
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
    /* Multi-line comment (fwrd-slash-star) check */
    else if(token[0] == '/' && token.length >= 2 && token[1]=='*')
    {
        return SymbolType.MULTI_LINE_COMMENT;
    }
    /* Single-line comment (fwrd-slash-slash) check */
    else if(token[0] == '/' && token.length >= 2 && token[1]=='/')
    {
        return SymbolType.SINGLE_LINE_COMMENT;
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

/** 
 * Determines whether the given token is
 * a mathematical operator
 *
 * Params:
 *   token = the `Token` to test
 * Returns: `true` if it is a mathematical
 * operator, `false` otherwise
 */
public bool isMathOp(Token token)
{
    string tokenStr = token.getToken();

    return tokenStr[0] == '+' || tokenStr[0] == '-' ||
            tokenStr[0] == '*' || tokenStr[0] == '/';
}

/** 
 * Determines whether the given token is
 * a binary operator, meaning one which
 * would be infixed/flanked by two operands
 * (one to the left and one to the right)
 *
 * Params:
 *   token = the `Token` to test
 * Returns: `true` if it is a binary
 * operator, `false` otherwise
 */
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
    else if(symbolIn == SymbolType.EQUALS)
    {
        return "==";
    }
    else if(symbolIn == SymbolType.SMALLER_THAN)
    {
        return "<";
    }
    else if(symbolIn == SymbolType.SMALLER_THAN_OR_EQUALS)
    {
        return "<=";
    }
    else if(symbolIn == SymbolType.GREATER_THAN)
    {
        return ">";
    }
    else if(symbolIn == SymbolType.GREATER_THAN_OR_EQUALS)
    {
        return ">=";
    }
    else if(symbolIn == SymbolType.AMPERSAND)
    {
        return "&";
    }
    else if(symbolIn == SymbolType.SEMICOLON)
    {
        return ";";
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
