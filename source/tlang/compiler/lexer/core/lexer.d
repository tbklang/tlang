/** 
 * Lexer interface definition
 */
module tlang.compiler.lexer.core.lexer;

import tlang.compiler.lexer.core.tokens : Token;
import std.ascii : isDigit, isAlpha, isWhite;

/** 
 * Defines the interface a lexer must provide
 * such that is can be used to source tokens
 * from in the parser
 */
public interface LexerInterface
{
    /** 
     * Returns the token at the current cursor
     * position
     *
     * Returns: the `Token`
     */
    public Token getCurrentToken();

    /** 
     * Moves the cursor one token forward
     */
    public void nextToken();

    /** 
     * Moves the cursor one token backwards
     */
    public void previousToken();

    /** 
     * Sets the position of the cursor
     *
     * Params:
     *   cursor = the new position
     */
    public void setCursor(ulong cursor);

    /** 
     * Retrieves the cursor's current position
     *
     * Returns: the position
     */
    public ulong getCursor();

    /** 
     * Checks whether more tokens are available
     * of not
     *
     * Returns: true if more tokens are available, false otherwise
     */
    public bool hasTokens();

    /** 
     * Get the line position of the lexer in the source text
     *
     * Returns: the position
     */
    public ulong getLine();

    /** 
     * Get the column position of the lexer in the source text
     *
     * Returns: the position
     */
    public ulong getColumn();

    /** 
     * Exhaustively provide a list of all tokens
     *
     * Returns: a `Token[]` containing all tokens
     */
    public Token[] getTokens();
}

/** 
 * Human-readable names assigned
 * to commonly used character
 * constants
 */
public enum LexerSymbols : char
{
    L_PAREN = '(',
    R_PAREN = ')',
    SEMI_COLON = ';',
    COMMA = ',',
    L_BRACK =  '[' ,
    R_BRACK =  ']' ,
    PLUS =  '+' ,
    MINUS =  '-' ,
    FORWARD_SLASH =  '/' ,
    PERCENT =  '%' ,
    STAR =  '*' ,
    AMPERSAND =  '&' ,
    L_BRACE =  '{' ,
    R_BRACE =  '}' ,
    EQUALS =  '=' ,
    SHEFFER_STROKE =  '|' ,
    CARET =  '^' ,
    EXCLAMATION =  '!' ,
    TILDE =  '~' ,
    DOT =  '.' ,
    COLON =  ':',
    SPACE = ' ',
    TAB = '\t',
    NEWLINE = '\n',
    DOUBLE_QUOTE = '"',
    SINGLE_QUOTE =  '\'' ,
    BACKSLASH =  '\\' ,
    UNDERSCORE =  '_' ,
    LESS_THAN =  '<' ,
    BIGGER_THAN =  '>' ,

    ESC_NOTHING =  '0' ,
    ESC_CARRIAGE_RETURN =  'r' ,
    ESC_TAB =  't' ,
    ESC_NEWLINE =  'n' ,
    ESC_BELL=  'a' ,

    ENC_BYTE =  'B' ,
    ENC_INT =  'I' ,
    ENC_LONG =  'L' ,
    ENC_WORD =  'W' ,
    ENC_UNSIGNED =  'U' ,
    ENC_SIGNED =  'S' ,
}

/** 
 * Alias to `LexerSymbols`
 */
public alias LS = LexerSymbols;

/** 
 * Checks if the provided character is an operator
 *
 * Params:
 *   c = the character to check
 * Returns: `true` if it is a character, `false`
 * otherwise
 */
public bool isOperator(char c)
{
    return c == LS.PLUS || c == LS.TILDE || c == LS.MINUS ||
           c == LS.STAR || c == LS.FORWARD_SLASH || c == LS.AMPERSAND ||
           c == LS.CARET || c == LS.EXCLAMATION || c == LS.SHEFFER_STROKE ||
           c == LS.LESS_THAN || c == LS.BIGGER_THAN;
}

/** 
 * Checks if the provided character is a splitter
 *
 * Params:
 *   c = the character to check
 * Returns: `true` if it is a splitter, `false`
 * otherwise
 */
public bool isSplitter(char c)
{
    return c == LS.SEMI_COLON || c == LS.COMMA || c == LS.L_PAREN ||
           c == LS.R_PAREN || c == LS.L_BRACK || c == LS.R_BRACK ||
           c == LS.PERCENT || c == LS.L_BRACE || c == LS.R_BRACE ||
           c == LS.EQUALS || c == LS.DOT || c == LS.COLON ||
           isOperator(c) || isWhite(c);
}

/** 
 * Checks if the provided character is a
 * numerical size encoder
 *
 * Params:
 *   character = the character to check
 * Returns: `true` if so, `false` otheriwse
 */
public bool isNumericalEncoder_Size(char character)
{
    return character == LS.ENC_BYTE || character == LS.ENC_WORD ||
           character == LS.ENC_INT || character == LS.ENC_LONG;
}

/** 
 * Checks if the provided character is a
 * numerical signage encoder
 *
 * Params:
 *   character = the character to check
 * Returns: `true` if so, `false` otherwise
 */
public bool isNumericalEncoder_Signage(char character)
{
    return character == LS.ENC_SIGNED || character == LS.ENC_UNSIGNED;
}

/** 
 * Checks if the given character is a valid
 * escape character (something which would 
 * have followed a `\`)
 *
 * Params:
 *   character = the character to check
 * Returns: `true` if so, `false` otherwise
 */
public bool isValidEscape_String(char character)
{
    return character == LS.BACKSLASH || character == LS.DOUBLE_QUOTE || character == LS.SINGLE_QUOTE ||
           character == LS.ESC_NOTHING || character == LS.ESC_NEWLINE  || character == LS.ESC_CARRIAGE_RETURN ||
           character == LS.TAB || character == LS.ESC_BELL;
}