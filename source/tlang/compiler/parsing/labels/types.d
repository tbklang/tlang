module tlang.compiler.parsing.labels.types;

import tlang.compiler.parsing.exceptions : ParserException;

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



public final class LabelException : ParserException
{
    this(string msg)
    {
        super(msg);
    }
}