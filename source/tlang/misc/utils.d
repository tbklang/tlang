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

/**
* Checks if the given character is a letter
*/
public bool isCharacterAlpha(char character)
{
    return (character >= 65 && character <= 90) || (character >= 97 && character <= 122);
}