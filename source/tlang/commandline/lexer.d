module compiler.lexer;

import std.container.slist;
import gogga;
import std.conv : to;

public final class Lexer
{
    /* The source to be lexed */
    private string sourceCode;

    /* The tokens */
    private string[] tokens;

    this(string sourceCode)
    {
        this.sourceCode = sourceCode;
    }

    /* Perform the lexing process */
    public void performLex()
    {
        // SList!(string) tokenThing;
        // tokenThing.insert("1");
        // tokenThing.insert("2");
        
        // import std.stdio;
        // writeln(tokenThing.front());
        // writeln(tokenThing.front());
        

        string[] currentTokens;
        string currentToken;
        ulong position;
        char currentChar;

        /* Whether we are in a string "we are here" or not */
        bool stringMode;

        bool escapeMode;

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
                    currentTokens ~= currentToken;
                    currentToken = "";
                }

                position++;
            }
            else if(isSpliter(currentChar) && !stringMode)
            {
                /* The splitter token to finally insert */
                string splitterToken;

                /* Check if we need to do combinators (e.g. for ||, &&) */
                /* TODO: Second operand in condition out of bounds */
                if(currentChar == '|' && (position+1) != sourceCode.length && sourceCode[position+1] == '|')
                {
                    splitterToken = "||";
                    position += 2;
                }
                else if(currentChar == '&' && (position+1) != sourceCode.length && sourceCode[position+1] == '&')
                {
                    splitterToken = "&&";
                    position += 2;
                }
                else
                {
                    splitterToken = ""~currentChar;
                    position++;
                }
                
                


                /* Flush the current token (if one exists) */
                if(currentToken.length)
                {
                    currentTokens ~= currentToken;
                    currentToken = "";
                }
                
                /* Add the splitter token */
                currentTokens ~= splitterToken;

                gprintln("FInished process");
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
                    currentTokens ~= currentToken;
                    currentToken = "";

                    /* Get out of string mode */
                    stringMode = false;
                }

                position++;
            }
            else if(currentChar == '\\')
            {
                /* You can only use these in strings */
                if(stringMode)
                {
                    /* Check if we have a next character */
                    if(position+1 != sourceCode.length && isValidEscape(sourceCode[position+1]))
                    {
                        /* Add to the string */
                        currentToken ~= "\\"~sourceCode[position+1];

                        position += 2;
                    }
                    /* If we don't have a next character then raise error */
                    else
                    {
                        gprintln("Unfinished escape sequence", DebugType.ERROR);
                    }
                }
                else
                {
                    gprintln("Escape sequences can only be used within strings", DebugType.ERROR);
                }
            }
            else
            {
                currentToken ~= currentChar;
                position++;
            }
        }

        /* If there was a token made at the end then flush it */
        if(currentToken.length)
        {
            currentTokens ~= currentToken;
        }

        tokens = currentTokens;
    }

    /* Return the tokens */
    public string[] getTokens()
    {
        return tokens;
    }

    /* TODO: We need to add pop functionality if we encounter || */
    private bool isSpliter(char character)
    {
        return character == ';' || character == ',' || character == '(' ||
                character == ')' || character == '[' || character == ']' ||
                character == '+' || character == '-' || character == '/' ||
                character == '%' || character == '*' || character == '&' ||
                character == '{' || character == '}' || character == '=' ||
                character == '|' || character == '^' || character == '!';
    }

    public bool isValidEscape(char character)
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
    assert(currentLexer.getTokens() == ["hello", "\"world\"",";"]);
}

/* Test input: `hello "world"|| ` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\"|| ";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello", "\"world\"","||"]);
}

/* Test input: `hello "world"||` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\"||";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello", "\"world\"","||"]);
}

/* Test input: `hello "world"|` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\";|";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello", "\"world\"",";", "|"]);
}

/* Test input: `     hello` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = " hello";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello"]);
}

/* Test input: `hello;` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = " hello;";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello", ";"]);
}

/* Test input: `hello "world\""` */
unittest
{
    import std.algorithm.comparison;
    string sourceCode = "hello \"world\\\"\"";
    Lexer currentLexer = new Lexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == ["hello", "\"world\\\"\""]);
}

