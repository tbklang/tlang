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
            else if(isSpliter(currentChar) && !stringMode)
            {
                /* Flush the current token (if one exists) */
                if(currentToken.length)
                {
                    currentTokens ~= currentToken;
                    currentToken = "";
                }
                
                /* Add the splitter token */
                currentTokens ~= ""~currentChar;

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

        /* If there was a token made at the end then flush it */
        if(currentToken.length)
        {
            currentTokens ~= currentToken;
        }

        tokens = currentTokens;
    }

    /* Return the tokens */
    public string[] getTokens()
    {
        return tokens;
    }

    /* TODO: We need to add pop functionality if we encounter || */
    private bool isSpliter(char character)
    {
        return character == ';' || character == ',' || character == '(' ||
                character == ')' || character == '[' || character == ']' ||
                character == '+' || character == '-' || character == '/' ||
                character == '%' || character == '*' || character == '&' ||
                character == '|' || character == '^' || character == '!';
    }
}