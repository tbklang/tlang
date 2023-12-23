/** 
 * A single-pass tokenizer
 */
module tlang.compiler.lexer.kinds.basic;

import std.container.slist;
import gogga;
import std.conv : to;
import std.ascii : isDigit, isAlpha, isWhite;
import tlang.compiler.lexer.core;

alias LS = LexerSymbols;
enum EMPTY = "";

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

            if (isWhite(currentChar))
            {
                /* TODO: Check if current token is fulled, then flush */
                if (currentToken.length != 0)
                {
                    flush();
                }

                bool run;
                if (currentChar == LS.NEWLINE) {
                    if (!advanceLine()) {
                        break;
                    }
                } else if (!advance()) {
                    break;
                }
            }
            else if (isSplitter(currentChar))
            {
                /* The splitter token to finally insert */
                string splitterToken;

                gprintln("Build up: " ~ currentToken);
                gprintln("Current char: " ~ currentChar);
                if (currentChar == LS.FORWARD_SLASH && isForward() && (sourceCode[position+1] == LS.FORWARD_SLASH || sourceCode[position+1] == LS.STAR)) {
                    if (!doComment()) {
                        break;
                    }
                }

                /* Check for case of `==` (where we are on the first `=` sign) */
                if (currentChar == LS.EQUALS && isForward() && sourceCode[position + 1] == LS.EQUALS)
                {
                    /* Flush any current token (if exists) */
                    if (currentToken.length)
                    {
                        currentTokens ~= new Token(currentToken, line, column);
                        currentToken = EMPTY;
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
                * preceding us were all good for an identifier
                */
                import misc.utils;

                if (currentChar == LS.DOT)
                {
                    if (isBackward() && isWhite(sourceCode[position - 1]))
                    {
                        throw new LexerException(this, "Character '.' is not allowed to follow a whitespace.");
                    }
                    if (isForward() && isWhite(sourceCode[position + 1]))
                    {
                        throw new LexerException(this, "Character '.' is not allowed to precede a whitespace.");
                    }
                    /* TODO: Error checking will need to be added */
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

                            currentToken ~= LS.DOT;

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
                        splitterToken = EMPTY ~ currentChar;
                        column++;
                        position++;
                    }

                }
                /* Check if we need to do combinators (e.g. for ||, &&) */
                /* TODO: Second operand in condition out of bounds */
                else if (currentChar == LS.SHEFFER_STROKE && isForward() && sourceCode[position + 1] == LS.SHEFFER_STROKE)
                {
                    splitterToken = "||";
                    column += 2;
                    position += 2;
                }
                else if (currentChar == LS.AMPERSAND && (position + 1) != sourceCode.length && sourceCode[position + 1] == LS.AMPERSAND)
                {
                    splitterToken = "&&";
                    column += 2;
                    position += 2;
                } else if (isWhite(currentChar)) {
                    if (currentChar == LS.NEWLINE) {
                        if (!advanceLine()) {
                            break;
                        }
                    } else if (!advance()) {
                        break;
                    }
                }
                else
                {
                    splitterToken = EMPTY ~ currentChar;
                    column++;
                    position++;
                }

                /* Flush the current token (if one exists) */
                if (currentToken.length)
                {
                    currentTokens ~= new Token(currentToken, line, column);
                    currentToken = EMPTY;
                }

                /* Add the splitter token (only if it isn't empty) */
                if (splitterToken.length)
                {
                    currentTokens ~= new Token(splitterToken, line, column);
                }
            }
            else if (currentChar == LS.DOUBLE_QUOTE)
            {
                if (!doString()) {
                    break;
                }
            }
            else if (currentChar == LS.BACKSLASH)
            {
                throw new LexerException(this, "Escape sequences can only be used within strings");
            }
            /* Character literal support */
            else if (currentChar == LS.SINGLE_QUOTE)
            {
                currentToken ~= LS.SINGLE_QUOTE;

                /* Character literal must be next */
                if (position + 1 != sourceCode.length)
                {
                    /* TODO: Escape support for \' */

                    /* Get the character */
                    currentToken ~= EMPTY ~ sourceCode[position + 1];
                    column++;
                    position++;

                    /* Closing ' must be next */
                    if (position + 1 != sourceCode.length && sourceCode[position + 1] == LS.SINGLE_QUOTE)
                    {
                        /* Generate and add the token */
                        currentToken ~= LS.SINGLE_QUOTE;
                        currentTokens ~= new Token(currentToken, line, column);

                        /* Flush the token */
                        currentToken = EMPTY;

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
            else if (isDigit(currentChar)){
                if (!doNumber()) {
                    break;
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

    private bool doString() {
        if (!buildAdvance()) {
            throw new LexerException(this, "Expected closing \", but got EOF");
        }
        while (true) {
            if (currentChar == LS.DOUBLE_QUOTE) {
                if (!buildAdvance) {
                    flush();
                    return false;
                }
                return true;
            } else if (currentChar == LS.BACKSLASH) {
                if (!doEscapeCode()) {
                    throw new LexerException(this, "Expected closing \", but got EOF");
                }
            } else if (currentChar == LS.NEWLINE) {
                throw new LexerException(this, "Expected closing \", but got NEWLINE");
            } else {
                if (!buildAdvance()) {
                    throw new LexerException(this, "Expected closing \", but got EOF");
                }
            }
        }
    }

    /** 
     * Lex a comment, start by consuming the '/' and setting a flag for multilLine based
     * on the next character and consume.
     * Enter a loop that looks for the end of the comment and if not builds up the comment.
     * 
     * Returns: true if characters left in buffer, else false
     */
    private bool doComment() {
        if (!buildAdvance()) {
            flush();
            /* TODO: perhaps error here */
            return false;
        }
        bool multiLine = currentChar == LS.STAR;
        if (!buildAdvance()) {
            flush();
        /* TODO: perhaps error here */
            return false;
        }
        while (true) {
            if (!multiLine && currentChar == LS.NEWLINE) {
                flush();
                return advanceLine();
            }
            if (multiLine && currentChar == LS.STAR && isForward() && sourceCode[position+1] == LS.FORWARD_SLASH) {
                buildAdvance();
                if (!buildAdvance()) {
                    flush();
                    return false;
                } else {
                    return true;
                }
            } else {
                if (!buildAdvance()) {
                    flush();
                    return false;
                }
            }
        }
    }

    /** 
     * Lex an escape code. If valid one id found, add it to the token, else throw Excecption
     * 
     * Returns: true if characters left in buffer, else false
     */
    private bool doEscapeCode() {
        if (!buildAdvance()) {
            return false;
        }
        // currentToken ~= LS.BACKSLASH;
        if (isValidEscape_String(currentChar)) {
            if (!buildAdvance()) {
                // flush();
                //TODO: Maybe throw error here
                return false;
            }
        } else {
            throw new LexerException(this, "Invalid escape code");
        }
        // flush();
        return true;
    }


    /** 
     * Lex a number, this method lexes a plain number, float or numerically encoded.
     * The Float and numerically encoded numbers are deferred to other methods.
     * 
     * Returns: true if characters left in buffer, else false
     */
    private bool doNumber() {
        while (true) {
            if (isDigit(currentChar)) {
                if(!buildAdvance()) {
                    flush();
                    return false;
                }
            } else if (currentChar == LS.DOT) {
                return doFloat();
            } else if (isNumericalEncoder(currentChar)) {
                return doEncoder();
            } else {
                return true;
            }
            // if (!advance()) {
            //     flush();
            //     return false;
            // }
        }
    }

    /** 
     * Lex a numberical encoder, looks for Signage follwed by Size, or if there is
     * no signage, jsut the size.
     * 
     * Returns: true if characters left in buffer, else false
     */
    private bool doEncoder() {
        if (isNumericalEncoder_Signage(currentChar)) {
            if (!buildAdvance() || !isNumericalEncoder_Size(currentChar)) {
                throw new LexerException(this, "Expected size indicator B,I,L,W but got EOF");
            }
        }
        if (isNumericalEncoder_Size(currentChar)) {
            if (!buildAdvance()) {
                flush();
                return false;
            } else {
                if (!isSplitter(currentChar)) {
                    throw new LexerException(this, "Expected splitter but got \"" ~ currentChar ~ "\".");
                }
            }
        }
        flush();
        return true;
    }

    /** 
     * Lex a floating point, the initial part of the number is lexed by the doNumber
     * method. Here we consume the '.' and consume digits until a splitter is reached.
     * 
     * Returns: true if characters left in buffer, else false
     */
    private bool doFloat() {
        if (!buildAdvance()) {
            throw new LexerException(this, "Floating point expected digit, got EOF.");
            //return false;
        }
        bool valid = false;
        while (true) {

            if (isDigit(currentChar))
            {
                /* tack on and move to next iteration */
                valid = true;
                if (!buildAdvance()) {
                    flush();
                    return false;
                }
                continue;
            }
            else
            {
                /* TODO: Throw erropr here */
                if (isSplitter(currentChar) && valid)
                {
                    flush();
                    return true;
                }
                else
                {
                    throw new LexerException(this, "Floating point '" ~ currentToken ~ "' cannot be followed by a '" ~ currentChar ~ "'");
                }
            }
        }
    }

    /** 
     * Flush the current token to the token buffer.
     */
    private void flush() {
        currentTokens ~= new Token(currentToken, line, column);
        currentToken = EMPTY;
    }

    /** 
     * Consume the current char into the current char
     */
    private bool buildAdvance() {
        currentToken ~= currentChar;
        return advance();
    }

    /** 
     * Advance the position, column and current token.
     * Returns: true if characters left in buffer, else false
     */
    private bool advance(int inc = 1) {
        column += inc;
        position += inc;
        if (position >= sourceCode.length) {
            return false;
        }
        currentChar = sourceCode[position];
        return true;
    }

    /** 
     * Advance the position, line and current token, reset the column to 1.
     * Returns: true if characters left in buffer, else false
     */
    private bool advanceLine(){
        column = 1;
        line++;
        position++;
        if (position >= sourceCode.length) {
            return false;
        }
        currentChar = sourceCode[position];
        return true;
    }

    private bool isSplitter(char character)
    {
        return character == LS.SEMI_COLON || character == LS.COMMA || character == LS.L_PAREN ||
            character == LS.R_PAREN || character == LS.L_BRACK || character == LS.R_BRACK ||
            character == LS.PLUS || character == LS.MINUS || character == LS.FORWARD_SLASH ||
            character == LS.PERCENT || character == LS.STAR || character == LS.AMPERSAND ||
            character == LS.L_BRACE || character == LS.R_BRACE || character == LS.EQUALS ||
            character == LS.SHEFFER_STROKE || character == LS.CARET || character == LS.EXCLAMATION ||
            character == LS.TILDE || character == LS.DOT || character == LS.COLON ||
            isWhite(character); //|| isNumericalEncoder(character);
    }

    /**
    * Given a character return whether it is valid entry for preceding a '.'.
    */
    private bool isValidDotPrecede(char character)
    {
        return character == LS.R_PAREN || character == LS.R_BRACK; // || isAlpha(character) || isDigit(character);
    }

    private bool isNumericalEncoder(char character)
    {
        return isNumericalEncoder_Size(character) ||
            isNumericalEncoder_Signage(character);
    }

    private bool isNumericalEncoder_Size(char character)
    {
        return character == LS.ENC_BYTE || character == LS.ENC_WORD ||
            character == LS.ENC_INT || character == LS.ENC_LONG;
    }

    private bool isNumericalEncoder_Signage(char character)
    {
        return character == LS.ENC_SIGNED || character == LS.ENC_UNSIGNED;
    }

    /* Supported escapes \" */
    public bool isValidEscape_String(char character)
    {
        return character == LS.BACKSLASH || character == LS.DOUBLE_QUOTE || character == LS.SINGLE_QUOTE
        || character == LS.ESC_NOTHING || character == LS.ESC_NEWLINE 
        || character == LS.ESC_CARRIAGE_RETURN || character == LS.TAB;
    }
}

/** 
 * Does a print out of some text just to show you
 * where you are from within the caller
 *
 * Params:
 *   __LINE__ = line number (auto-filled)
 *   __MODULE__ = module name (auto-filled)
 *   __FUNCTION__ = function name (auto-filled)
 */
private void shout(int i = __LINE__, string mod = __MODULE__, string func = __FUNCTION__)
{
    gprintln("Unittest at "~to!(string)(i)~" in "~func~" (within module "~mod~")");
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

/* Test input: `hello \n "world";` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \n \"world\";";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0)
        ]);
}

/* Test input: `hello "wo\nrld";` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "hello \"wo\nrld\";";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    try {
        currentLexer.performLex();
        gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
        assert(currentLexer.getTokens() == [
                new Token("hello", 0, 0), new Token("\"wo\nrld\"", 0, 0),
                new Token(";", 0, 0)
            ]);
        assert(false);
    } catch (LexerException) {
        assert(true);

    }
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

/* Test input: `//trist` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "//trist";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("//trist", 0, 0)]);
}

/* Test input: `/*trist\*\/` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "/*trist*/";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*trist*/", 0, 0)]);
}

/* Test input: `/*t\nr\ni\ns\nt\*\/` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "/*t\nr\ni\ns\nt*/";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*t\nr\ni\ns\nt*/", 0, 0)]);
}

/* Test input: `/*t\nr\ni\ns\nt\*\/ ` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "/*t\nr\ni\ns\nt*/ ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*t\nr\ni\ns\nt*/", 0, 0)]);
}

/* Test input: `//trist \n hello` */
unittest
{
    import std.algorithm.comparison;

    string sourceCode = "//trist \n hello";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("//trist ", 0, 0),
        new Token("hello", 0, 0),
        ]);
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

    /* 21U (invalid) */
    sourceCode = "21U ";
    currentLexer = new BasicLexer(sourceCode);
    // gprintln(currentLexer.performLex());
    try {
        currentLexer.performLex();
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));
        assert(false);
    } catch (LexerException) {
        assert(true);
    }

    /* 21ULa (invalid) */
    sourceCode = "21ULa";
    currentLexer = new BasicLexer(sourceCode);
    // gprintln(currentLexer.performLex());
    try {
        currentLexer.performLex();
        gprintln("Collected "~to!(string)(currentLexer.getTokens()));
        assert(false);
    } catch (LexerException) {
        assert(true);
    }

    /* 21UL (valid) */
    sourceCode = "21SI";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21SI", 0, 0)]);

    /* 21UL; (valid) */
    sourceCode = "21SI;";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    gprintln("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("21SI", 0, 0),
        new Token(";", 0, 0)
        ]);
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
    * Testing Float EOF after '.'.
    * Test calssification: Invalid
    * Test input: `1.`
    */
    sourceCode = "1.";
    currentLexer = new BasicLexer(sourceCode);
    try
    {
        currentLexer.performLex();
        assert(false);
    }
    catch (LexerException e)
    {
    }
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
