module tlang.commandline.error_handling;

import tlang.misc.exceptions : TError;
import tlang.compiler.typecheck.dependency.exceptions : DependencyException;

import tlang.misc.messaging;
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
    // TODO: Format things way better now
    // error(e.msg);
    

    string subSystem = "";
    string message = e.msg;

    if(cast(DependencyException)e)
    {
        subSystem = "depgen";
    }

    // error(message, subSystem);
    error(message);
    exit(-1);
}