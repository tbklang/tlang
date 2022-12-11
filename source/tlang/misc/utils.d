module misc.utils;

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


/** 
 * Takes in a symbol name (string) and replaces
 * all the "."s with an underscore as to make
 * the names ready for ceoe emitting
 *
 * Params:
 *   symbolIn = The symbol name to transform
 * Returns: The transformed symbol name 
 */
public string symbolRename(string symbolIn)
{
    string symbolOut = replace(symbolIn, ".", "_");
    return symbolOut;
}