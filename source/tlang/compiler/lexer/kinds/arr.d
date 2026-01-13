module tlang.compiler.lexer.kinds.arr;

import tlang.compiler.lexer.core;

/** 
 * An array-based tokenizer which takes a
 * provided array of `Token[]`. useful
 * for testing parser-only related things
 * with concrete tokens
 */
public final class ArrLexer : LexerInterface
{
    /** 
     * The concrete token source
     */
    private Token[] tokens;

    /** 
     * Position in the `tokens` array
     */
    private ulong tokenPtr = 0;

    /** 
     * Constructs a new `ArrLexer` (dummy lexer) with
     * the tokens already in concrete form in the
     * provided array.
     *
     * Params:
     *   tokens = the `Token[]`
     */
    this(Token[] tokens)
    {
        this.tokens = tokens;
    }

    /** 
     * Returns the token at the current cursor
     * position
     *
     * Returns: the `Token`
     */
    public Token getCurrentToken()
    {
        return tokens[tokenPtr];
    }

    /** 
     * Moves the cursor one token forward
     */
    public void nextToken()
    {
        tokenPtr++;
    }

    /** 
     * Moves the cursor one token backwards
     */
    public void previousToken()
    {
        tokenPtr--;
    }

    /** 
     * Sets the position of the cursor
     *
     * Params:
     *   cursor = the new position
     */
    public void setCursor(ulong cursor)
    {
        this.tokenPtr = cursor;
    }

    /** 
     * Retrieves the cursor's current position
     *
     * Returns: the position
     */
    public ulong getCursor()
    {
        return this.tokenPtr;
    }

    /** 
     * Checks whether more tokens are available
     * of not
     *
     * Returns: true if more tokens are available, false otherwise
     */
    public bool hasTokens()
    {
        return tokenPtr < tokens.length;
    }

    /** 
     * Get the line position of the lexer in the source text
     *
     * Returns: the position
     */
    public ulong getLine()
    {
        return 0; // TODO: anything meaningful?
    }

    /** 
     * Get the column position of the lexer in the source text
     *
     * Returns: the position
     */
    public ulong getColumn()
    {
        return 0; // TODO: anything meaningful?
    }

    /** 
     * Exhaustively provide a list of all tokens
     *
     * Returns: a `Token[]` containing all tokens
     */
    public Token[] getTokens()
    {
        return tokens;
    }

    /**
     * Removes the token at the given position
     *
     * Params:
     *   cursor = the position of the token
     * to remove
     */
    public void removeToken(ulong cursor)
    {
        // TODO: Do sanity check
        Token[] newList;
        for(ulong i = 0; i < this.tokens.length; i++)
        {
            if(i != cursor)
            {
                newList ~= this.tokens[i];
            }
        }
        this.tokens = newList;
    }

    /**
     * Inserts the given token at the given
     * position
     *
     * Params:
     *   token = the token to insert
     *   cursor = the position to insert at
     */
    public void insertToken(Token token, ulong cursor)
    {
        // TODO: Do sanity check
        Token[] newList;
        for(ulong i = 0; i < this.tokens.length; i++)
        {
            if(i != cursor)
            {
                newList ~= this.tokens[i];
            }
            else
            {
                newList ~= token;
            }
        }
        this.tokens = newList;
    }
}