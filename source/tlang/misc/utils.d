module tlang.misc.utils;

import std.string : cmp;
import std.array : replace;

public bool isPresent(string[] arr, string t)
{
    foreach(string j; arr)
    {
        if(cmp(j, t) == 0)
        {
            return true;
        }
    }

    return false;
}

/**
* Checks if the given character is a letter
*/
public bool isCharacterAlpha(char character)
{
    return (character >= 65 && character <= 90) || (character >= 97 && character <= 122);
}

/**
* Checks if the given character is a number
*/
public bool isCharacterNumber(char character)
{
    return (character >= 48 && character <= 57);
}





template Stack(T)
{
    public final class Stack
    {
        import std.container.slist : SList;

        private SList!(T) queue;

        public void push(T item)
        {
            queue.insertFront(item);
        }

        public T pop()
        {
            //FIXME: Handling for emoty stack
            T stackTop = queue.front();
            queue.removeFront();

            return stackTop;
        }
    }
}

/** 
 * Crashes the calling process
 * with the given message
 *
 * Params:
 *   msg = the message
 */
public noreturn panic(string msg = "")
{
    // TODO: Add this to niknaks rather
    // ... and make it have a nice exit
    import tlang.misc.logging;
    ERROR("panic!"~(msg.length ? ": "~msg : ""));
    import core.stdc.stdlib : exit;
    exit(1);
}

/** 
 * Performs an assertion check and
 * on failure panics, potentially
 * with an optional custom message
 *
 * Params:
 *   b = the value to test
 *   msg = (Optional) the message to
 * crash with if the assertion fails
 */
public void ass(bool b, string msg = "")
{
    if(!b)
    {
        panic(msg);
    }
}