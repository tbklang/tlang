module compiler.lexer;

import std.container.slist;
import gogga;
import std.conv : to;
import std.string : cmp;

/* TODO: Add Token type (which matches column and position too) */
public final class Token
{
    /* The token */
    private string token;

    /* Line number information */
    private ulong line, column;

    this(string token, ulong line, ulong column)
    {
        this.token = token;
        this.line = line;
        this.column = column;
    }

    override bool opEquals(Object other)
    {
        return cmp(token, (cast(Token)other).getToken()) == 0;
    }

    override string toString()
    {
        /* TODO (Column number): Don't adjust here, do it maybe in the lexer itself */
        return token~" at ("~to!(string)(line)~", "~to!(string)(column-token.length)~")";
    }

    public string getToken()
    {
        return token;
    }
}

public final class Lexer
{
    /**
    * Lexer state data
    */
    private string sourceCode; /* The source to be lexed */
    private ulong line = 1; /* Current line */
    private ulong column = 1;
    private Token[] currentTokens; /* Current token set */
    private string currentToken; /* Current token */
    private ulong position; /* Current character position */
    private char currentChar; /* Current character */
    private bool stringMode; /* Whether we are in a string "we are here" or not */

    /* The tokens */
    private Token[] tokens;

    this(string sourceCode)
    {
        this.sourceCode = sourceCode;
    }

    private bool isForward()
    {
        return position+1 < sourceCode.length;
    }

    public bool isBackward()
    {
        return position-1 < sourceCode.length;
    }

    /**
    * Used for tokenising a2.b2
    *
    * When the `.` is encountered
    * and there are some characters
    * behind it this checks if we can
    * append a further dot to it
    */
    private bool isBuildUpValidIdent()
    {
        import compiler.symbols.check;
        return isPathIdentifier(currentToken) || isIdentifier(currentToken);
    }

    /**
    * Returns true if we have a token being built
    * false otherwise
    */
    private bool hasToken()
    {
        return currentToken.length != 0;
    }

    /* Perform the lexing process */
    /* TODO: Use return value */
    public bool performLex()
    {

        while(position < sourceCode.length)
        {
            // gprintln("SrcCodeLen: "~to!(string)(sourceCode.length));
            // gprintln("Position: "~to!(string)(position));

            currentChar = sourceCode[position];

            if(currentChar == ' ' && !stringMode)
            {
                /* TODO: Check if current token is fulled, then flush */
                if(currentToken.length != 0)
                {
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = "";
                }

                column++;
                position++;
            }
            else if(isSpliter(currentChar) && !stringMode)
            {
                /* The splitter token to finally insert */
                string splitterToken;


                /**
                * Here we check if we have a `.` and that the characters
                * preceding us were all godd for an identifier
                */
                import misc.utils;
                
                if(currentChar == '.' && hasToken() && isBuildUpValidIdent())
                {
                    gprintln("Bruh");
                    /**
                    * Now we check that we have a character infront of us
                    * and that it is a letter
                    *
                    * TODO: Add _ check too as that is a valid identifier start
                    */
                    if(isForward() && isCharacterAlpha(sourceCode[position+1]))
                    {
                        position++;
                        column+=1;

                        currentToken ~= '.';

                        continue;
                    }
                    else
                    {
                        gprintln("Expected a letter to follow the .", DebugType.ERROR);
                        return false;
                    }
                    
                }
                /* Check if we need to do combinators (e.g. for ||, &&) */
                /* TODO: Second operand in condition out of bounds */
                else if(currentChar == '|' && (position+1) != sourceCode.length && sourceCode[position+1] == '|')
                {
                    splitterToken = "||";
                    column += 2;
                    position += 2;
                }
                else if(currentChar == '&' && (position+1) != sourceCode.length && sourceCode[position+1] == '&')
                {
                    splitterToken = "&&";
                    column += 2;
                    position += 2;
                }
                else if (currentChar == '\n') /* TODO: Unrelated!!!!!, but we shouldn't allow this bahevaipur in string mode */
                {
                    line++;
                    column = 1;

                    position++;
                }
                else
                {
                    splitterToken = ""~currentChar;
                    column++;
                    position++;
                }
                

                /* Flush the current token (if one exists) */
                if(currentToken.length)
                {
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = "";
                }
                
                /* Add the splitter token (only if it isn't empty) */
                if(splitterToken.length)
                {
                    currentTokens ~= new Token(splitterToken, line, column);
                }
            }
            else if(currentChar == '"')
            {
                /* If we are not in string mode */
                if(!stringMode)
                {
                    /* Add the opening " to the token */
                    currentToken ~= '"';

                    /* Enable string mode */
                    stringMode = true;
                }
                /* If we are in string mode */
                else
                {
                    /* Add the closing " to the token */
                    currentToken ~= '"';

                    /* Flush the token */
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = "";

                    /* Get out of string mode */
                    stringMode = false;
                }

                column++;
                position++;
            }
            else if(currentChar == '\\')
            {
                /* You can only use these in strings */
                if(stringMode)
                {
                    /* Check if we have a next character */
                    if(position+1 != sourceCode.length && isValidEscape_String(sourceCode[position+1]))
                    {
                        /* Add to the string */
                        currentToken ~= "\\"~sourceCode[position+1];

                        column += 2;
                        position += 2;
                    }
                    /* If we don't have a next character then raise error */
                    else
                    {
                        gprintln("Unfinished escape sequence", DebugType.ERROR);
                        return false;
                    }
                }
                else
                {
                    gprintln("Escape sequences can only be used within strings", DebugType.ERROR);
                    return false;
                }
            }
            /* Character literal support */
            else if(!stringMode && currentChar == '\'')
            {
                currentToken ~= "'";

                /* Character literal must be next */
                if(position+1 != sourceCode.length)
                {
                    /* TODO: Escape support for \' */

                    /* Get the character */
                    currentToken ~= ""~sourceCode[position+1];
                    column++;
                    position++;


                    /* Closing ' must be next */
                    if(position+1 != sourceCode.length && sourceCode[position+1] == '\'')
                    {
                        /* Generate and add the token */
                        currentToken ~= "'";
                        currentTokens ~= new Token(currentToken, line, column);

                        /* Flush the token */
                        currentToken = "";

                        column += 2;
                        position += 2;
                    }
                    else
                    {
                        gprintln("Was expecting closing ' when finishing character literal", DebugType.ERROR);
                        return false;
                    }
                }
                else
                {
                    gprintln("EOSC reached when trying to get character literal", DebugType.ERROR);
                    return false;
                }
            }
            else
            {
                currentToken ~= currentChar;
                column++;
                position++;
            }
        }

        /* If there was a token made at the end then flush it */
        if(currentToken.length)
        {
            currentTokens ~= new Token(currentToken, line, column);
        }

        tokens = currentTokens;

        return true;
    }

    /* Return the tokens */
    public Token[] getTokens()
    {
        return tokens;
    }

    private bool isSpliter(char character)
    {
        return character == ';' || character == ',' || character == '(' ||
                character == ')' || character == '[' || character == ']' ||
                character == '+' || character == '-' || character == '/' ||
                character == '%' || character == '*' || character == '&' ||
                character == '{' || character == '}' || character == '=' ||
                character == '|' || character == '^' || character == '!' ||
                character == '\n' || character == '~' || character =='.';
    }

    /* Supported escapes \" */
    public bool isValidEscape_String(char character)
    {
        return true; /* TODO: Implement me */
    }
}

/* Test input: `hello "world";` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\";";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token("\"world\"", 0, 0), new Token(";", 0, 0)]);
}

/* Test input: `hello "world"|| ` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\"|| ";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token("\"world\"", 0, 0), new Token("||", 0, 0)]);
}

/* Test input: `hello "world"||` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\"||";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token("\"world\"", 0, 0), new Token("||", 0, 0)]);
}

/* Test input: `hello "world"|` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\";|";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token("\"world\"", 0, 0), new Token(";", 0, 0), new Token("|", 0, 0)]);
}

/* Test input: `     hello` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = " hello";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0)]);
}

/* Test input: `hello;` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = " hello;";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token(";", 0, 0)]);
}

/* Test input: `hello "world\""` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\\\"\"";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0), new Token("\"world\\\"\"", 0, 0)]);
}

/* Test input: `'c'` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "'c'";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("'c'", 0, 0)]);
}

/* Test input: `2121\n2121` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "2121\n2121";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("2121", 0, 0), new Token("2121", 0, 0)]);
}



/* TODO: Add more tests */