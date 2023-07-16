/** 
 * A single-pass tokenizer
 */
module tlang.compiler.lexer.kinds.basic;

import std.container.slist;
import gogga;
import std.conv : to;
import std.ascii : isDigit, isAlpha, isWhite;
import tlang.compiler.lexer.core;

/** 
 * Represents a basic lexer which performs the whole tokenization
 * process in one short via a call to `performLex()`, only after
 * this may the `LexerInterface` methods, such as `getCurrentToken()`,
 * `nextToken()` and so forth, actually be used.
 *
 * This is effectively a single pass lexer.
 */
public final class BasicLexer : LexerInterface
{
    /** 
     * Post-perform lex() data
     *
     * This exports the LexerInterface API.
     *
     * To-do, ensure these can only be used AFTER `performLex()`
     * has been called.
     */
    private ulong tokenPtr = 0;

    /** 
     * Returns the token at the current cursor
     * position
     *
     * Returns: the `Token`
     */
    public override Token getCurrentToken()
    {
        /* TODO: Throw an exception here when we try get more than we can */
        return tokens[tokenPtr];
    }

    /** 
     * Moves the cursor one token forward
     */
    public override void nextToken()
    {
        tokenPtr++;
    }

    /** 
     * Moves the cursor one token backwards
     */
    public override void previousToken()
    {
        tokenPtr--;
    }

    /** 
     * Sets the position of the cursor
     *
     * Params:
     *   newPosition = the new position
     */
    public override void setCursor(ulong newPosition)
    {
        tokenPtr = newPosition;
    }

    /** 
     * Retrieves the cursor's current position
     *
     * Returns: the position
     */
    public override ulong getCursor()
    {
        return tokenPtr;
    }

    /** 
     * Checks whether more tokens are available
     * of not
     *
     * Returns: true if more tokens are available, false otherwise
     */
    public override bool hasTokens()
    {
        return tokenPtr < tokens.length;
    }

    /** 
     * Get the line position of the lexer in the source text
     *
     * Returns: the position
     */
    public override ulong getLine()
    {
        return this.line;
    }

    /** 
     * Get the column position of the lexer in the source text
     *
     * Returns: the position
     */
    public override ulong getColumn()
    {
        return this.column;
    }

    /** 
     * Exhaustively provide a list of all tokens
     *
     * Returns: a `Token[]` containing all tokens
     */
    public override Token[] getTokens()
    {
        return tokens;
    }

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
    private bool floatMode; /* Whether or not we are building a floating point constant */

    /* The tokens */
    private Token[] tokens;

    this(string sourceCode)
    {
        this.sourceCode = sourceCode;
    }

    private bool isForward()
    {
        return position + 1 < sourceCode.length;
    }

    public bool isBackward()
    {
        return position - 1 < sourceCode.length;
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
        import tlang.compiler.symbols.check;

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
    public void performLex()
    {

        while (position < sourceCode.length)
        {
            // gprintln("SrcCodeLen: "~to!(string)(sourceCode.length));
            // gprintln("Position: "~to!(string)(position));

            currentChar = sourceCode[position];

            if (floatMode == true)
            {
                if (isDigit(currentChar))
                {
                    /* tack on and move to next iteration */
                    currentToken ~= currentChar;
                    position++;
                    column++;
                    continue;
                }
                /* TODO; handle closer case and error case */
            else
                {
                    /* TODO: Throw erropr here */
                    if (isSplitter(currentChar))
                    {
                        floatMode = false;
                        currentTokens ~= new Token(currentToken, line, column);
                        currentToken = "";

                        /* We just flush and catch splitter in next round, hence below is commented out */
                        // column++;                        
                        // position++;
                    }
                    else
                    {
                        throw new LexerException(this, "Floating point '" ~ currentToken ~ "' cannot be followed by a '" ~ currentChar ~ "'");
                    }
                }
            }
            /* Discard spaces and tabs that are not necessary*/
            else if (isWhite(currentChar) && !stringMode)
            {
                /* TODO: Check if current token is fulled, then flush */
                if (currentToken.length != 0)
                {
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = "";
                }

                column++;
                position++;
            }
            else if (isSplitter(currentChar) && !stringMode)
            {
                /* The splitter token to finally insert */
                string splitterToken;

                gprintln("Build up: " ~ currentToken);
                gprintln("Current char: " ~ currentChar);

                /* Check for case of `==` (where we are on the first `=` sign) */
                if (currentChar == '=' && isForward() && sourceCode[position + 1] == '=')
                {
                    /* Flush any current token (if exists) */
                    if (currentToken.length)
                    {
                        currentTokens ~= new Token(currentToken, line, column);
                        currentToken = "";
                    }

                    // Create the `==` token
                    currentTokens ~= new Token("==", line, column);

                    // Skip over the current `=` and the next `=`
                    position += 2;

                    column += 2;

                    continue;
                }

                /**
                * Here we check if we have a `.` and that the characters
                * preceding us were all godd for an identifier
                */
                import misc.utils;

                if (currentChar == '.')
                {
                    if (isBackward() && isWhite(sourceCode[position - 1]))
                    {
                        throw new LexerException(this, "Character '.' is not allowed to follow a whitespace.");
                    }
                    if (isForward() && isWhite(sourceCode[position + 1]))
                    {
                        throw new LexerException(this, "Character '.' is not allowed to precede a whitespace.");
                    }
                    /* FIXME: Add floating point support here */
                    /* TODO: IF buildUp is all numerical and we have dot go into float mode */
                    /* TODO: Error checking will need to be added */
                    if (isNumericalStr(currentToken))
                    {
                        /* Tack on the dot */
                        currentToken ~= ".";

                        /* Enable floating point mode and go to next iteration*/
                        floatMode = true;
                        gprintln(
                            "Float mode just got enabled: Current build up: \"" ~ currentToken ~ "\"");
                        column++;
                        position++;
                        continue;
                    }
                    else if (hasToken() && isBuildUpValidIdent())
                    {

                        gprintln("Bruh");
                        /**
                    * Now we check that we have a character infront of us
                    * and that it is a letter
                    *
                    * TODO: Add _ check too as that is a valid identifier start
                    */
                        if (isForward() && isCharacterAlpha(sourceCode[position + 1]))
                        {
                            position++;
                            column += 1;

                            currentToken ~= '.';

                            continue;
                        }
                        else
                        {
                            throw new LexerException(this, "Expected a letter to follow the .");
                        }
                    }
                    else if (!hasToken() && (isForward() && !isValidDotPrecede(
                            sourceCode[position - 1])))
                    {
                        throw new LexerException(this, "Character '.' should be preceded by valid identifier or numerical.");
                    }
                    else
                    {
                        splitterToken = "" ~ currentChar;
                        column++;
                        position++;
                    }

                }
                /* Check if we need to do combinators (e.g. for ||, &&) */
                /* TODO: Second operand in condition out of bounds */
            else if (currentChar == '|' && (position + 1) != sourceCode.length && sourceCode[position + 1] == '|')
                {
                    splitterToken = "||";
                    column += 2;
                    position += 2;
                }
                else if (currentChar == '&' && (position + 1) != sourceCode.length && sourceCode[position + 1] == '&')
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
                    splitterToken = "" ~ currentChar;
                    column++;
                    position++;
                }

                /* Flush the current token (if one exists) */
                if (currentToken.length)
                {
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = "";
                }

                /* Add the splitter token (only if it isn't empty) */
                if (splitterToken.length)
                {
                    currentTokens ~= new Token(splitterToken, line, column);
                }
            }
            else if (currentChar == '"')
            {
                /* If we are not in string mode */
                if (!stringMode)
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
            else if (currentChar == '\\')
            {
                /* You can only use these in strings */
                if (stringMode)
                {
                    /* Check if we have a next character */
                    if (position + 1 != sourceCode.length && isValidEscape_String(
                            sourceCode[position + 1]))
                    {
                        /* Add to the string */
                        currentToken ~= "\\" ~ sourceCode[position + 1];

                        column += 2;
                        position += 2;
                    }
                    /* If we don't have a next character then raise error */
                else
                    {
                        throw new LexerException(this, "Unfinished escape sequence");
                    }
                }
                else
                {
                    throw new LexerException(this, "Escape sequences can only be used within strings");
                }
            }
            /* Character literal support */
            else if (!stringMode && currentChar == '\'')
            {
                currentToken ~= "'";

                /* Character literal must be next */
                if (position + 1 != sourceCode.length)
                {
                    /* TODO: Escape support for \' */

                    /* Get the character */
                    currentToken ~= "" ~ sourceCode[position + 1];
                    column++;
                    position++;

                    /* Closing ' must be next */
                    if (position + 1 != sourceCode.length && sourceCode[position + 1] == '\'')
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
                        throw new LexerException(this, "Was expecting closing ' when finishing character literal");
                    }
                }
                else
                {
                    throw new LexerException(this, LexerError.EXHAUSTED_CHARACTERS, "EOSC reached when trying to get character literal");
                }
            }
            /**
            * If we are building up a number
            *
            * TODO: Build up token right at the end (#DuplicateCode)
            */
            else if (isBuildUpNumerical())
            {
                gprintln("jfdjkhfdjkhfsdkj");
                /* fetch the encoder segment */
                char[] encoderSegment = numbericalEncoderSegmentFetch();

                gprintln("isBuildUpNumerical(): Enter");

                /**
                * If we don't have any encoders
                */
                if (encoderSegment.length == 0)
                {
                    /* We can add a signage encoder */
                    if (isNumericalEncoder_Signage(currentChar))
                    {
                        gprintln("Hello");

                        /* Check if the next character is a size (it MUST be) */
                        if (isForward() && isNumericalEncoder_Size(sourceCode[position + 1]))
                        {
                            currentToken ~= currentChar;
                            column++;
                            position++;

                        }
                        else
                        {
                            throw new LexerException(this, "You MUST specify a size encoder after a signagae encoder");
                        }

                    }
                    /* We can add a size encoder */
                else if (isNumericalEncoder_Size(currentChar))
                    {
                        currentToken ~= currentChar;
                        column++;
                        position++;
                    }
                    /* We can add more numbers */
                else if (isDigit(currentChar))
                    {
                        currentToken ~= currentChar;
                        column++;
                        position++;
                    }
                    /* Splitter (TODO) */
                else if (isSplitter(currentChar))
                    {
                        /* Add the numerical literal as a new token */
                        currentTokens ~= new Token(currentToken, line, column);

                        /* Add the splitter token if not a newline */
                        if (currentChar != '\n')
                        {
                            currentTokens ~= new Token("" ~ currentChar, line, column);
                        }

                        /* Flush the token */
                        currentToken = "";

                        /* TODO: Check these */
                        column += 2;
                        position += 2;
                    }
                    /* Anything else is invalid */
                else
                    {
                        throw new LexerException(this, "Not valid TODO");
                    }
                }
                /**
                * If we have one encoder
                */
            else if ((encoderSegment.length == 1))
                {
                    /* Check what the encoder is */

                    /**
                    * If we had a signage then we must have a size after it
                    */
                    if (isNumericalEncoder_Signage(encoderSegment[0]))
                    {
                        /**
                        * Size encoder must then follow
                        */
                        if (isNumericalEncoder_Size(currentChar))
                        {
                            currentToken ~= currentChar;
                            column++;
                            position++;

                            /* Add the numerical literal as a new token */
                            currentTokens ~= new Token(currentToken, line, column);

                            /* Flush the token */
                            currentToken = "";

                        }
                        /**
                        * Anything else is invalid
                        */
                    else
                        {
                            throw new LexerException(this, "A size-encoder must follow a signage encoder");
                        }
                    }
                    else
                    {
                        throw new LexerException(this, "Cannot have another encoder after a size encoder");
                    }
                }
                /* It is impossible to reach this as flushing means we cannot add more */
            else
                {
                    assert(false);
                }

            }
            /* Any other case, keep building the curent token */
            else
            {
                currentToken ~= currentChar;
                column++;
                position++;
            }
        }

        /* If there was a token made at the end then flush it */
        if (currentToken.length)
        {
            currentTokens ~= new Token(currentToken, line, column);
        }

        tokens = currentTokens;
    }

    private char[] numbericalEncoderSegmentFetch()
    {
        char[] numberPart;
        ulong stopped;
        for (ulong i = 0; i < currentToken.length; i++)
        {
            char character = currentToken[i];

            if (isDigit(character))
            {
                numberPart ~= character;
            }
            else
            {
                stopped = i;
                break;
            }
        }

        char[] remaining = cast(char[]) currentToken[stopped .. currentToken.length];

        return remaining;
    }

    /**
    * Returns true if the current build up is entirely
    * numerical
    *
    * FIXME: THis, probably by its own will pick up `UL`
    * as a number, or even just ``
    */
    private bool isBuildUpNumerical()
    {
        import std.ascii : isDigit;

        char[] numberPart;
        ulong stopped;
        for (ulong i = 0; i < currentToken.length; i++)
        {
            char character = currentToken[i];

            if (isDigit(character))
            {
                numberPart ~= character;
            }
            else
            {
                stopped = i;
                break;
            }
        }

        /**
        * We need SOME numerical stuff
        */
        if (stopped == 0)
        {
            return false;
        }

        char[] remaining = cast(char[]) currentToken[stopped .. currentToken.length];

        char lstEncoder;

        for (ulong i = 0; i < remaining.length; i++)
        {
            char character = remaining[i];

            if (!isNumericalEncoder(character))
            {
                return false;
            }
        }

        return true;

    }

    /**
    * Given a string return true if all characters
    * are digits, false otherwise and false if
    * the string is empty
    */
    private static bool isNumericalStr(string input)
    {
        /**
        * If the given input is empty then return false
        */
        if (input.length == 0)
        {
            return false;
        }

        /** 
         * If there are any characters in the string then
         * check if all are digits
         */
        for (ulong i = 0; i < input.length; i++)
        {
            char character = input[i];

            if (!isDigit(character))
            {
                return false;
            }
        }

        return true;
    }

    private bool isSplitter(char character)
    {
        return character == ';' || character == ',' || character == '(' ||
            character == ')' || character == '[' || character == ']' ||
            character == '+' || character == '-' || character == '/' ||
            character == '%' || character == '*' || character == '&' ||
            character == '{' || character == '}' || character == '=' ||
            character == '|' || character == '^' || character == '!' ||
            character == '~' || character == '.' || character == ':' ||
            isWhite(character); //|| isNumericalEncoder(character);
    }

    /**
    * Given a character return whether it is valid entry for preceding a '.'.
    */
    private bool isValidDotPrecede(char character)
    {
        return character == ')' || character == ']'; // || isAlpha(character) || isDigit(character);
    }

    private bool isNumericalEncoder(char character)
    {
        return isNumericalEncoder_Size(character) ||
            isNumericalEncoder_Signage(character);
    }

    private bool isNumericalEncoder_Size(char character)
    {
        return character == 'B' || character == 'W' ||
            character == 'I' || character == 'L';
    }

    private bool isNumericalEncoder_Signage(char character)
    {
        return character == 'S' || character == 'U';
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
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0)
        ]);
}

/* Test input: `hello "world"|| ` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\"|| ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token("||", 0, 0)
        ]);
}

/* Test input: `hello "world"||` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\"||";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token("||", 0, 0)
        ]);
}

/* Test input: `hello "world"|` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\";|";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0), new Token("|", 0, 0)
        ]);
}

/* Test input: `     hello` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = " hello";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0)]);
}

/* Test input: `hello;` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = " hello;";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token(";", 0, 0)
        ]);
}

/* Test input: `hello "world\""` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\\\"\"";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\\\"\"", 0, 0)
        ]);
}

/* Test input: `'c'` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "'c'";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("'c'", 0, 0)]);
}

/* Test input: `2121\n2121` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "2121\n2121";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("2121", 0, 0), new Token("2121", 0, 0)
        ]);
}

/**
* Test `=`` and `==` handling
*/
unittest
{
    import std.algorithm.comparison;

    string sourceCode = " =\n";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("=", 0, 0)]);

    import std.algorithm.comparison;

    sourceCode = " = ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("=", 0, 0), new Token("==", 0, 0)
        ]);

    import std.algorithm.comparison;

    sourceCode = " ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("==", 0, 0)]);

    import std.algorithm.comparison;

    sourceCode = " = =\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("=", 0, 0), new Token("=", 0, 0)
        ]);

    import std.algorithm.comparison;

    sourceCode = " ==, = ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("==", 0, 0), new Token(",", 0, 0), new Token("=", 0, 0),
            new Token("==", 0, 0)
        ]);

    // Test flushing of previous token
    import std.algorithm.comparison;

    sourceCode = "i==i=\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("i", 0, 0), new Token("==", 0, 0), new Token("i", 0, 0),
            new Token("=", 0, 0)
        ]);
}

/**
* Test: Literal value encoding
*
* Tests validity
*/
unittest
{
    import std.algorithm.comparison;

    string sourceCode;
    BasicLexer currentLexer;

    /* 21L (valid) */
    sourceCode = "21L";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21L", 0, 0)]);

    /* 21UL (valid) */
    sourceCode = "21UL";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21UL", 0, 0)]);

    // /* 21U (invalid) */
    // sourceCode = "21U ";
    // currentLexer = new Lexer(sourceCode);
    // // gprintln(currentLexer.performLex());
    // bool status = currentLexer.performLex();
    // gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    // assert(!status);

    // /* 21UL (valid) */
    // sourceCode = "21UL";
    // currentLexer = new Lexer(sourceCode);
    // currentLexer.performLex();
    // gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    // assert(currentLexer.getTokens() == [new Token("21UL", 0, 0)]);

}

/* Test input: `1.5` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "1.5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("1.5", 0, 0)]);
}

/**
* Test correct handling of dot-operator for
* non-floating point cases
*
* Input: `new A().l.p.p;`
*/
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "new A().l.p.p;";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("new", 0, 0),
            new Token("A", 0, 0),
            new Token("(", 0, 0),
            new Token(")", 0, 0),
            new Token(".", 0, 0),
            new Token("l.p.p", 0, 0),
            new Token(";", 0, 0)
        ]);
}

/**
* Tab testing
*/
unittest
{
    /**
    * Test tab dropping in front of a float.
    * Test calssification: Valid
    * Test input: `\t1.5`
    */
    gprintln("Tab Unit Test");
    import std.algorithm.comparison;

    string sourceCode = "\t1.5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("1.5", 0, 0)]);

    /**
    * Test tab dropping before '.' of float.
    * Catch fail for verification.
    * Test calssification: Invalid
    * Test input: `1\t.5`
    */
    import std.algorithm.comparison;

    bool didFail = false;
    sourceCode = "1\t.5";
    currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException e)
    {
        didFail = true;
    }
    assert(didFail);

    /**
    * Test tab dropping after '.' of float.
    * Catch fail for verification.
    * Test calssification: Invalid
    * Test input: `1.\t5`
    */
    import std.algorithm.comparison;

    didFail = false;
    sourceCode = "1.\t5";
    currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException e)
    {
        didFail = true;
    }
    assert(didFail);

    /**
    * Test tab dropping for an empty token array.
    * Test calssification: Valid
    * Test input: `\t\t\t\t\t`
    */
    gprintln("Tab Unit Test");
    import std.algorithm.comparison;

    sourceCode = "\t\t\t\t\t";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens().length == 0);
}

/**
* Test correct handling of dot-operator for
* non-floating point cases where whitespace has been inserted before and after.
* Test Classification: Invalid
*
* Input: `new A() . l.p.p;`
*/
unittest
{
    import std.algorithm.comparison;

    bool didFail = false;
    string sourceCode = "new A() . l.p.p;";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException)
    {
        didFail = true;
    }
    assert(didFail);
}

unittest
{

    /**
    * Test dot for fail on dot operator with no buildup and invalid lead
    * Catch fail for verification.
    * Test calssification: Invalid
    * Test input: `1.5.5`
    */
    import std.algorithm.comparison;

    bool didFail = false;
    string sourceCode = "1.5.5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException e)
    {
        didFail = true;
    }
    assert(didFail);

    /**
    * Test for fail on space following dot operator.
    * Test Classification: Invalid
    * Input: `1. a`
    */
    didFail = false;
    sourceCode = "1. a";
    currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException e)
    {
        didFail = true;
    }
    assert(didFail);

    /**
    * Test for correct lex space following paren
    * Test Classification: Valid
    * Input: `).x`
    */
    sourceCode = ").x";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token(")", 0, 0),
            new Token(".", 0, 0),
            new Token("x", 0, 0),
        ]);
    /**
    * Test for fail on space preceding dot operator.
    * Test Classification: Invalid
    * Input: `1 .a`
    */
    didFail = false;
    sourceCode = "1 .a";
    currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
    }
    catch (LexerException e)
    {
        didFail = true;
    }
    assert(didFail);
}

/**
* Test newlines 
* Test Classification: Valid
* Input: `\n\n\n\n`
*/
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "\n\n\n\n";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens().length == 0);
}
