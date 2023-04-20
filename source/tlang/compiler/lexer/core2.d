module tlang.compiler.lexer.core2;

import tlang.compiler.lexer.tokens : Token;

public interface LexerInterface
{
    public Token getCurrentToken();

    public void nextToken();

    public void previousToken();

    public void setCursor(ulong);

    public ulong getCursor();
}