module tlang.compiler.lexer.streamer;

import tlang.compiler.lexer.core2 : LexerInterface;

public class StreamingLexer : LexerInterface
{
    // TODO: Later on, we can make it even take in a File if
    // ... you want and even stream bit-by-bit from that
    // ... we'd need to cache that ofc as well to be able
    // ... to support re-winding the lexer
    this(string sourceCode)
    {
        
    }
}