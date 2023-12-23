/** 
 * Lexer interface definition
 */
module tlang.compiler.lexer.core.lexer;

import tlang.compiler.lexer.core.tokens : Token;

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

public enum LexerSymbols: char {
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