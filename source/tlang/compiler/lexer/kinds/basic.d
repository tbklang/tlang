/** 
 * A single-pass tokenizer
 */
module tlang.compiler.lexer.kinds.basic;

import std.container.slist;
import std.string : replace;
import tlang.misc.logging;
import std.conv : to;
import std.ascii : isDigit, isAlpha, isWhite;
import tlang.compiler.lexer.core;

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

    /** 
     * Constructs a new lexer with the given
     * source code of which is should tokenize
     *
     * Params:
     *   sourceCode = the source text
     */
    this(string sourceCode)
    {
        this.sourceCode = sourceCode;
    }

    /** 
     * Checks whether or not we could shift our
     * source text pointer forward if it would
     * be within the boundries of the source text
     * or not
     *
     * Returns: `true` if within the boundries,
     * `false` otherwise
     */
    private bool isForward()
    {
        return position + 1 < sourceCode.length;
    }

    /** 
     * Checks whether or not we could shift our
     * source text pointer backwards and it it
     * would be within the boundries of the source
     * text or not
     *
     * Returns: `true` if within the boundries,
     * `false` otherwise
     */
    private bool isBackward()
    {
        return position - 1 < sourceCode.length;
    }

    /**
    * Returns true if we have a token being built
    * false otherwise
    *
    * Returns: `true` if we have a token built-up,
    * `false` otherwise
    */
    private bool hasToken()
    {
        return currentToken.length != 0;
    }

    /** 
     * Performs the lexing process
     *
     * Throws:
     *  LexerException on error tokenizing
     */
    public void performLex()
    {

        currentChar = sourceCode[position];
        while (position < sourceCode.length)
        {
            // gprintln("SrcCodeLen: "~to!(string)(sourceCode.length));
            // gprintln("Position: "~to!(string)(position));


            // // currentChar = sourceCode[position];
            // gprintln("Current Char\"" ~ currentChar ~ "\"");
            // gprintln("Current Token\"" ~ currentToken ~ "\"");
            // gprintln("Match alpha check" ~ to!(bool)(currentChar == LS.UNDERSCORE || isAlpha(currentChar)));

            if (isSplitter(currentChar))
            {

                if (currentToken.length != 0)
                {
                    flush();
                }
                if (isWhite(currentChar) ) {
                    if (improvedAdvance()) {
                        continue;
                    } else {
                        break;
                    }
                }                /* The splitter token to finally insert */
                string splitterToken;

                // gprintln("Build up: " ~ currentToken);
                // gprintln("Current char, splitter: " ~ currentChar);
                if (currentChar == LS.FORWARD_SLASH && isForward() && (sourceCode[position+1] == LS.FORWARD_SLASH || sourceCode[position+1] == LS.STAR)) {
                    if (!doComment()) {
                        break;
                    }
                }

                /* Check for case of `==` or `=<` or `=>` (where we are on the first `=` sign) */
                if (currentChar == LS.EQUALS && isForward() && (sourceCode[position + 1] == LS.EQUALS || sourceCode[position + 1] == LS.LESS_THAN || sourceCode[position + 1] == LS.BIGGER_THAN))
                {
                    buildAdvance();
                    buildAdvance();
                    flush();
                    continue;
                }

                /* Check for case of `<=` or `>=` */
                if ((currentChar == LS.LESS_THAN || currentChar == LS.BIGGER_THAN) && isForward() && (sourceCode[position + 1] == LS.EQUALS || sourceCode[position + 1] == LS.LESS_THAN || sourceCode[position + 1] == LS.BIGGER_THAN))
                {
                    buildAdvance();
                    buildAdvance();
                    flush();
                    continue;
                }

                /**
                * Here we check if we have a `.` and that the characters
                * preceding us were all good for an identifier
                */
                import tlang.misc.utils;

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
                    else if (!hasToken() && (isBackward() && !isValidDotPrecede(
                            sourceCode[position - 1])))
                    {
                        throw new LexerException(this, "Character '.' should be preceded by valid identifier or numerical.");
                    }
                    else
                    {
                        splitterToken = EMPTY ~ currentChar;
                        improvedAdvance();
                    }
                }else if (currentChar == LS.AMPERSAND && (position + 1) != sourceCode.length && sourceCode[position + 1] == LS.AMPERSAND)
                {
                    splitterToken = "&&";
                    improvedAdvance(2, false);
                } 
                /* Check if we need to do combinators (e.g. for ||, &&) */
                /* TODO: Second operand in condition out of bounds */
                else if (currentChar == LS.SHEFFER_STROKE && isForward() && sourceCode[position + 1] == LS.SHEFFER_STROKE)
                {
                    splitterToken = "||";
                    improvedAdvance(2, false);
                } else if (currentChar == LS.EXCLAMATION && isForward() && sourceCode[position + 1] == LS.EQUALS)
                {
                    splitterToken = "!=";
                    improvedAdvance(2, false);
                }else if (currentChar == LS.SHEFFER_STROKE) {
                    splitterToken = "|";
                    improvedAdvance(1, false);
                } else if (currentChar == LS.AMPERSAND) {
                    splitterToken = "&";
                    improvedAdvance(1, false);
                } else if (currentChar == LS.CARET) {
                    splitterToken = "^";
                    improvedAdvance(1, false);
                } else if (currentChar == LS.LESS_THAN) {
                    splitterToken = [LS.LESS_THAN];
                    improvedAdvance(1, false);
                } else if (currentChar == LS.BIGGER_THAN) {
                    splitterToken = [LS.BIGGER_THAN];
                    improvedAdvance(1, false);
                }  
                else if (isWhite(currentChar)) {
                    if (!improvedAdvance()) {
                        break;
                    }
                }
                else
                {
                    splitterToken = EMPTY ~ currentChar;
                    improvedAdvance();
                }

                /* Flush the current token (if one exists) */
                if (currentToken.length)
                {
                    flush();
                }

                /* Add the splitter token (only if it isn't empty) */
                if (splitterToken.length)
                {
                    currentTokens ~= new Token(splitterToken, line, column);
                }
            }
            //else if (currentChar == LS.UNDERSCORE || ((!isSplitter(currentChar) && !isDigit(currentChar)) && currentChar != LS.DOUBLE_QUOTE && currentChar != LS.SINGLE_QUOTE && currentChar != LS.BACKSLASH)) {
            else if (currentChar == LS.UNDERSCORE || isAlpha(currentChar)) {
                DEBUG("path ident String");
                if (!doIdentOrPath()) {
                    break;
                } else {
                    continue;
                }
            }
            else if (currentChar == LS.DOUBLE_QUOTE)
            {
                if (!doString()) {
                    break;
                }
            }
            else if (currentChar == LS.SINGLE_QUOTE)
            {
                if (!doChar()) {
                    break;
                }
            }
            else if (isDigit(currentChar)){
                if (!doNumber()) {
                    break;
                }
                currentToken = currentToken.replace("_", "");
            }
            else if (currentChar == LS.BACKSLASH)
            {
                throw new LexerException(this, "Escape sequences can only be used within strings");
            } else {
                throw new LexerException(this, "Unsupported Character in this position");
                //gprintln("Fuck " ~ " me col" ~ to!(string)(column));
            }
        }

        /* If there was a token made at the end then flush it */
        if (currentToken.length)
        {
            currentTokens ~= new Token(currentToken, line, column);
        }

        tokens = currentTokens;
    }

    /** 
     * Processes an ident with or without a dot-path
     *
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doIdentOrPath () {
        if (!buildAdvance()) {
            flush();
            return false;
        }

        while (true) {
            if (currentChar == LS.DOT) {
                if (isForward() && (isSplitter(sourceCode[position + 1]) || isDigit(sourceCode[position + 1]))) {
                    throw new LexerException(this, "Invalid character in identifier build up.");
                } else {
                    if (!buildAdvance()) {
                        throw new LexerException(this, "Invalid character in identifier build up.");
                        //return false;
                    }
                }
            } else if (isSplitter(currentChar)) {
                flush();
                return true;
            } else if (!(isAlpha(currentChar) || isDigit(currentChar) || currentChar == LS.UNDERSCORE)) {
                throw new LexerException(this, "Invalid character in identifier build up.");
            } else {
                if (!buildAdvance()) {
                    return false;
                }
            }
        }
    }

    /** 
     * Tokenizes a character
     *
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doChar()
    {
        if(!buildAdvance())
        {
            throw new LexerException(this, "Expected character,  but got EOF");
        }
        /* Character literal must be next */
        bool valid;
        if(currentChar == LS.BACKSLASH)
        {
            valid = doEscapeCode();
        }
        else
        {
            valid = buildAdvance();
        }
        if(!valid)
        {
            throw new LexerException(this, "Expected ''',  but got EOF");
        }

        if(currentChar != LS.SINGLE_QUOTE)
        {
            throw new LexerException(this, "Expected ''',  but got EOF");
        }
        if(!buildAdvance())
        {
            flush();
            return false;
        }
        flush();
        return true;
    }

    /** 
     * Tokenizes a string
     *
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doString()
    {
        if(!buildAdvance())
        {
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
     * Lex a comment, start by consuming the '/' and setting a flag for
     * multi-line based on the next character and consume.
     *
     * Enters a loop that looks for the end of the comment and if not
     * builds up the comment.
     * 
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doComment() {
        buildAdvance();
        // if (!buildAdvance()) {
        //     flush();
        //     return false;
        // }
        bool multiLine = currentChar == LS.STAR;
        if (!buildAdvance()) {
            if (multiLine) {
                throw new LexerException(this, "Expected closing Comment, but got EOF");
            } else {
            flush();
            return false;
            }
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
                    if (multiLine)
                    {
                        throw new LexerException(this, "Expected closing Comment, but got EOF");
                    }
                    else
                    {
                        flush();
                        return false;
                    }
                }
            }
        }
    }

    /** 
     * Lex an escape code. If valid one id found, add it to the token, else throw Exception
     * 
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doEscapeCode() {
        if (!buildAdvance()) {
            return false;
        }
        // currentToken ~= LS.BACKSLASH;
        if (isValidEscape_String(currentChar)) {
            return buildAdvance();
        } else {
            throw new LexerException(this, "Invalid escape code");
        }
        // flush();
    }


    /** 
     * Lex a number, this method lexes a plain number, float or numerically encoded.
     * The Float and numerically encoded numbers are deferred to other methods.
     * 
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doNumber() {
        while (true) {
            if (isDigit(currentChar) || currentChar == LS.UNDERSCORE) {
                if(!buildAdvance()) {
                    currentToken = currentToken.replace("_", "");
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
        }
    }

    /** 
     * Lex a numerical encoder, looks for Signage followed by Size, or if there is
     * no signage, just the size.
     * 
     * Returns: `true` if characters left in buffer, else `false`
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
     * Lex a floating point, the initial part of the number is lexed by the `doNumber()`
     * method. Here we consume the '.' and consume digits until a splitter is reached.
     * 
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool doFloat() {
        if (!buildAdvance()) {
            throw new LexerException(this, "Floating point expected digit, got EOF.");
            //return false;
        }
        size_t count = 0;
        bool valid = false;
        while (true) {

            if (isDigit(currentChar) || (count > 0 && currentChar == LS.UNDERSCORE))
            {
                /* tack on and move to next iteration */
                valid = true;
                if (!buildAdvance()) {
                    currentToken = currentToken.replace("_", "");
                    flush();
                    return false;
                }
                count++;
                continue;
            }
            else
            {
                /* TODO: Throw erropr here */
                if (isSplitter(currentChar) && valid)
                {
                    currentToken = currentToken.replace("_", "");
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
    private void flush()
    {
        currentTokens ~= new Token(currentToken, line, column);
        currentToken = EMPTY;
    }

    /** 
     * Consume the current char into the current token
     *
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool buildAdvance()
    {
        currentToken ~= currentChar;
        return improvedAdvance();
    }

    /** 
     * Advances the source code pointer
     *
     * Params:
     *   inc = advancement counter, default 1  
     *   shouldFlush = whether or not to flush, default is `false`
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool improvedAdvance(int inc = 1, bool shouldFlush = false)
    {
        if (currentChar == LS.NEWLINE)
        {
            shouldFlush && flush();
            line++;
            column = 1;
            position++;
        }
        else
        {
            column += inc;
            position += inc;
        }

        if (position >= sourceCode.length)
        {
            return false;
        }
        currentChar = sourceCode[position];
        return true;
    }

    /** 
     * Advance the position, line and current token, reset the column to 1.
     *
     * Returns: `true` if characters left in buffer, else `false`
     */
    private bool advanceLine()
    {
        column = 1;
        line++;
        position++;
        if (position >= sourceCode.length)
        {
            return false;
        }
        currentChar = sourceCode[position];
        return true;
    }
}

version(unittest)
{
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
        DEBUG("Unittest at "~to!(string)(i)~" in "~func~" (within module "~mod~")");
    }
}

/**
 * Test input: `hello "world";`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\";";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0)
        ]);
}

/**
 * Test input: `hello \n "world";`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \n \"world\";";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0)
        ]);
}

/**
 * Test input: `hello "wo\nrld";`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"wo\nrld\";";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    try {
        currentLexer.performLex();
    } catch (LexerException) {
        assert(true);

    }
}

/**
 * Test input: `hello "world"|| `
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\"|| ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token("||", 0, 0)
        ]);
}

/**
 * Test input: `hello "world"&& `
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\"&& ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token("&&", 0, 0)
        ]);
}

/**
 * Test input: `hello "wooorld"||`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"wooorld\"||";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"wooorld\"", 0, 0),
            new Token("||", 0, 0)
        ]);
}

/**
 * Test input: `hello "world"|`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\";|";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\"", 0, 0),
            new Token(";", 0, 0), new Token("|", 0, 0)
        ]);
}

/**
 * Test input: `     hello`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = " hello";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("hello", 0, 0)]);
}

/**
 * Test input: `//trist`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "//trist";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("//trist", 0, 0)]);
}

/**
 * Test input: `/*trist\*\/`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "/*trist*/";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*trist*/", 0, 0)]);
}

/**
 * Test input: `/*t\nr\ni\ns\nt\*\/`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "/*t\nr\ni\ns\nt*/";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*t\nr\ni\ns\nt*/", 0, 0)]);
}

/**
 * Test input: `/*t\nr\ni\ns\nt\*\/ `
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "/*t\nr\ni\ns\nt*/ ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("/*t\nr\ni\ns\nt*/", 0, 0)]);
}

/**
 * Test input: `//trist \n hello`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "//trist \n hello";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("//trist ", 0, 0),
        new Token("hello", 0, 0),
        ]);
}

/**
 * Test input: `hello;`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = " hello;";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token(";", 0, 0)
        ]);
}

/**
 * Test input: `5+5`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "5+5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("5", 0, 0),
            new Token("+", 0, 0),
            new Token("5", 0, 0),
        ]);
}

/**
 * Test input: `hello "world\""`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "hello \"world\\\"\"";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("hello", 0, 0), new Token("\"world\\\"\"", 0, 0)
        ]);
}

/**
 * Test input: `'c'`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "'c'";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("'c'", 0, 0)]);
}

/**
 * Test input: `2121\n2121`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "2121\n2121";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("2121", 0, 0), new Token("2121", 0, 0)
        ]);
}

/**
 * Test `=`` and `==` handling
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = " =\n";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("=", 0, 0)]);

    import std.algorithm.comparison;

    sourceCode = " = ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("=", 0, 0), new Token("==", 0, 0)
        ]);

    import std.algorithm.comparison;

    sourceCode = " ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("==", 0, 0)]);

    import std.algorithm.comparison;

    sourceCode = " = =\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("=", 0, 0), new Token("=", 0, 0)
        ]);

    import std.algorithm.comparison;

    sourceCode = " ==, = ==\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("==", 0, 0), new Token(",", 0, 0), new Token("=", 0, 0),
            new Token("==", 0, 0)
        ]);

    // Test flushing of previous token
    import std.algorithm.comparison;

    sourceCode = "i==i=\n";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
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
    shout();
    import std.algorithm.comparison;

    string sourceCode;
    BasicLexer currentLexer;

    /* 21L (valid) */
    sourceCode = "21L";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21L", 0, 0)]);

    /* 21UL (valid) */
    sourceCode = "21UL";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21UL", 0, 0)]);

    /* 21U (invalid) */
    sourceCode = "21U ";
    currentLexer = new BasicLexer(sourceCode);
    // gprintln(currentLexer.performLex());
    try {
        currentLexer.performLex();
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
        assert(false);
    } catch (LexerException) {
        assert(true);
    }

    /* 21UL (valid) */
    sourceCode = "21SI";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [new Token("21SI", 0, 0)]);

    /* 21UL; (valid) */
    sourceCode = "21SI;";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected "~to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("21SI", 0, 0),
        new Token(";", 0, 0)
        ]);
}

/**
 * Test input: `1.5`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "1.5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
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
    shout();
    import std.algorithm.comparison;

    string sourceCode = "new A().l.p.p;";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
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
    shout();
    /**
    * Test tab dropping in front of a float.
    * Test calssification: Valid
    * Test input: `\t1.5`
    */
    DEBUG("Tab Unit Test");
    import std.algorithm.comparison;

    string sourceCode = "\t1.5";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
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
    * Testing illegal backslash.
    * Test calssification: Invalid
    * Test input: `1.`
    */
    sourceCode = "hello \\ ";
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
    DEBUG("Tab Unit Test");
    import std.algorithm.comparison;

    sourceCode = "\t\t\t\t\t";
    currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens().length == 0);
}

/**
 * Test correct handling of dot-operator for
 * non-floating point cases where whitespace has been inserted before and after.
 * Test Classification: Invalid
 *
 * Input: `new A() .l.p.p;`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    bool didFail = false;
    string sourceCode = "new A(). l.p.p;";
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

/**
 * Test correct handling of dot-operator for
 * non-floating point cases where whitespace has been inserted before and after.
 * Test Classification: Invalid
 *
 * Input: `new A() . l.p.p;`
 */
unittest
{
    shout();
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
    shout();

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
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
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
    shout();
    import std.algorithm.comparison;

    string sourceCode = "\n\n\n\n";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens().length == 0);
}

/**
 * Test for character escape codes
 *
 * Input: `'\\'`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "'\\\\'";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("'\\\\'", 0, 0),
        ]);
}

/**
 * Test for character escape codes
 *
 * Input: `'\a'`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "'\\a'";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("'\\a'", 0, 0),
        ]);
}

/**
 * Test for invalid escape sequence
 * Input: `'\f'`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\\f";
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
}

/**
 * Test for invalid char in ident
 * Input: `hello$k`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "hello$k";
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
}

/**
 * Test for invalid char in ident
 * Input: `$`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "$";
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
}

/**
 * Testing Underscores in numbers
 *
 * Input: `1_ 1_2 1_2.3 1_2.3_ 1__2 1__2.3 1__.23__`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "1_ 1_2 1_2.3 1_2.3_ 1__2 1__2.3 1__.23__";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("1", 0, 0),
            new Token("12", 0, 0),
            new Token("12.3", 0, 0),
            new Token("12.3", 0, 0),
            new Token("12", 0, 0),
            new Token("12.3", 0, 0),
            new Token("1.23", 0, 0),
        ]);
}

/**
 * Testing Comparison in numbers
 *
 * Input: `<= >= ==`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "<= >= =< => == != < > ^";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("<=", 0, 0),
            new Token(">=", 0, 0),
            new Token("=<", 0, 0),
            new Token("=>", 0, 0),
            new Token("==", 0, 0),
            new Token("!=", 0, 0),
            new Token("<", 0, 0),
            new Token(">", 0, 0),
            new Token("^", 0, 0),
        ]);
}

/**
 * Testing Chars
 *
 * Input: `'a'`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "'a'";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
            new Token("'a'", 0, 0),
        ]);
}

/**
 * Test for invalid ident
 * Input: `hello. `
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "hello. ";
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
}

/**
 * Test for invalid ident
 * Input: `hello.`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "hello.";
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
}

/**
 * Testing Chars
 * Input: `'`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "'";
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
}

/**
 * Testing Chars
 * Input: `'a`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "'a";
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
}

/**
 * Testing Chars
 * Input: `'aa`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "'aa";
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
}

/**
 * Testing String EOF
 * Input: `"a`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\"a";
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
}

/**
 * Testing String EOF
 * Input: `"a`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\"";
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
}

/**
 * Testing String EOF
 * Input: `"\`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\"\\";
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
}

/**
 * Testing Comment EOF
 * Input: `/*`
 */
unittest
{
    shout();
   
    bool didFail = false;
    string sourceCode = "/*";
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
}

/**
 * Testing Comment EOF
 * Input: `/* `
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "/* ";
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
}

/**
* Testing Line comment EOF
*
* Input: `//`
*/
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "//";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("//", 0, 0)
        ]);
}

/**
 * Testing invalid Escape Code
 * Input: `\p`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\"\\p";
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
}

/**
 * Testing invalid Escape Code
 * Input: `\p`
 */
unittest
{
    shout();
    
    bool didFail = false;
    string sourceCode = "\\p";
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
}

/**
 * Testing comment
 *
 * Input: `'a' `
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "'a' ";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("'a'", 0, 0)
        ]);
}

/**
 * Testing comment
 *
 * Input: `// \n`
 */
unittest
{
    shout();
    import std.algorithm.comparison;

    string sourceCode = "// \n";
    BasicLexer currentLexer = new BasicLexer(sourceCode);
    currentLexer.performLex();
    DEBUG("Collected " ~ to!(string)(currentLexer.getTokens()));
    assert(currentLexer.getTokens() == [
        new Token("// ", 0, 0)
        ]);
}
