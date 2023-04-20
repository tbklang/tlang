module tlang.compiler.lexer.streamer;

import tlang.compiler.lexer.core2 : LexerInterface;
import tlang.compiler.lexer.tokens : Token;

public class StreamingLexer : LexerInterface
{
    // TODO: Later on, we can make it even take in a File if
    // ... you want and even stream bit-by-bit from that
    // ... we'd need to cache that ofc as well to be able
    // ... to support re-winding the lexer
    this(string sourceCode)
    {
        
    }

    public override bool hasTokens()
    {
        return true;
    }

    public override void nextToken()
    {

    }

    public override void previousToken()
    {

    }

    public override Token getCurrentToken()
    {
        return null;
    }

    public override void setCursor(ulong cursor)
    {

    }

    public override ulong getCursor()
    {
        return 0;
    }

    public override ulong getLine()
    {
        return 0;
    }

    public override ulong getColumn()
    {
        return 0;
    }

    public override Token[] getTokens()
    {
        return [];
    }
}