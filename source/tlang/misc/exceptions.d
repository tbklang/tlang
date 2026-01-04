module tlang.misc.exceptions;

public class TError : Exception
{
    private string _ss;

    this(string subSystem, string message)
    {
        /* Generate eerror message using gogga */
        //byte[] messageBytes = generateMessage(message, DebugType.ERROR);
        /* TODO: Check the vnode for path of fd 0, dont vt100 is not tty device */

        //super(messageBytes);

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