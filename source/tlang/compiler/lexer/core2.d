module tlang.compiler.lexer.core2;

import tlang.compiler.lexer.tokens : Token;

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