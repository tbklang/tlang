/** 
 * Routines used for handling any
 * `TError`(s) that occur during
 * command-line usage
 */
module tlang.commandline.error_handling;

// base exception type
import tlang.misc.exceptions : TError;

// logging-related and misc.
import tlang.misc.messaging : error;
import core.stdc.stdlib : exit;

/** 
 * Handles any T-lang based errors (`TError`(s))
 * and specifically formats them to look nice on
 * the command-line for user consumption.
 *
 * Params:
 *   e = the `TError`
 */
public void handleError(TError e) @noreturn
{
    string subSystem = e.getSubSystem();
    string message = e.msg;
    error(subSystem, message);

    // then exit
    exit(-1);
}