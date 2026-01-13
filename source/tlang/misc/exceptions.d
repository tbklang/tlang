/**
 * Base error type definitions
 */
module tlang.misc.exceptions;

/** 
 * Base type for all error types in
 * the TLang compiler
 */
public abstract class TError : Exception
{
    private string _ss;

    this(string subSystem, string message)
    {
        super(message);
        this._ss = subSystem;
    }

    this(string message)
    {
        this("<unknown subsystem>", message);
    }

    public string getSubSystem()
    {
        // TODO: Return to this._ss == "" and this._ss == null
        // the former allocates zero-space but gives a pointer?
        // (and sets size to 0)
        // and the other doesn't (sets pointer to null) and size
        // to 0
        // return this._ss == null;

        return this._ss;
    }
}