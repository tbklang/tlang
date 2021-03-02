module compiler.lexer;

public final class Lexer
{
    /* The source to be lexed */
    private string sourceCode;

    /* The tokens */
    private string[] tokens;

    this(string sourceCode)
    {
        this.sourceCode = sourceCode;
    }

    /* Perform the lexing process */
    public void performLex()
    {
        string[] currentTokens;
        string currentToken;
        ulong position;
        char currentChar;

        bool stringMode;

        while(position != sourceCode.length)
        {
            currentChar = sourceCode[position];

            if(currentChar == ' ' && !stringMode)
            {
                /* TODO: Check if current token is fulled, then flush */
                if(currentToken.length != 0)
                {
                    currentTokens ~= currentToken;
                    currentToken = "";
                }

                position++;
            }
            else if(currentChar == ';' && !stringMode)
            {
                /* Flush the current token */
                currentTokens ~= currentToken;
                currentToken = "";

                /* Add the ; token */
                currentTokens ~= ";";

                position++;
            }
            else if(currentChar == '"')
            {
                /* If we are not in string mode */
                if(!stringMode)
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
                    currentTokens ~= currentToken;
                    currentToken = "";

                    /* Get out of string mode */
                    stringMode = false;
                }

                position++;
            }
            else
            {
                currentToken ~= currentChar;
                position++;
            }
        }

        /* When we end we don't flush the last token, flush it now */
        currentTokens ~= currentToken;


        tokens = currentTokens;
    }

    /* Return the tokens */
    public string[] getTokens()
    {
        return tokens;
    }
}