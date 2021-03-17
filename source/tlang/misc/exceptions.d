module misc.exceptions;

import gogga : generateMessage;

public class TError : Exception
{
    this(string message)
    {
        /* Generate eerror message using gogga */
        byte[] messageBytes = generateMessage(message, DebugType.ERROR);
        /* TODO: Check the vnode for path of fd 0, dont vt100 is not tty device */

        super(messageBytes);
    }
}