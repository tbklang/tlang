module misc.utils;

import std.string : cmp;

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