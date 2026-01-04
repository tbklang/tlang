/** 
 * This provides all the routines to be used
 * when user-oriented logging is to be done.
 *
 * User-oriented logging is defined as anything
 * that would be important to let the user
 * know about, hence debugging logs are not
 * considered patt of this definition.
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.misc.messaging;

// FIXME: Make use of dlog and a custom transformer
import dlog.basic : Level, FileHandler;

import std.array : join;
import std.stdio : stderr;

byte[] WARN_COLOR = [27, '[', '3', '3', 'm'];
byte[] ERROR_COLOR = [27, '[', '3', '1', 'm'];
byte[] INFO_COLOR = [27, '[', '3', '2', 'm'];
byte[] TIP_COLOR = [27, '[', '3', '6', 'm'];

byte[] RESET = [27, '[', 'm'];



// Use this for messages that are warnings
public void warn(T...)(T[] args)
{
    stderr.write(WARN_COLOR);
    string s = join(args, " ");
    stderr.write(s);
    stderr.write(RESET);
}

// Use this for any messages that are informative
// tips
public void tip(T...)(T[] args)
{
    stderr.write(TIP_COLOR);
    string s = join(args, " ");
    stderr.write(s);
    stderr.write(RESET);
}

// Use this for any messages indicating an error
public void error(T...)(T[] args)
{
    stderr.write(ERROR_COLOR);
    string s = join(args, " ");
    stderr.write(s);
    stderr.write(RESET);
}

// Use this for any messages indicating an informative
// message
public void info(T...)(T[] args)
{
    stderr.write(INFO_COLOR);
    string s = join(args, " ");
    stderr.write(s);
    stderr.write(RESET);
}