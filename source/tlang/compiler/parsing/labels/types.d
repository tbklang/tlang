module tlang.compiler.parsing.labels.types;

/**
 * Represents a label
 */
public struct Label
{
    private string _n;
    this(string name)
    {
        this._n = name;
    }

    public string name()
    {
        return this._n;
    }
}

import tlang.compiler.parsing.exceptions : ParserException;

public final class LabelException : ParserException
{
    
}