/** 
 * Type definitions for emit module
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.emit.types;

import std.datetime : Duration;

/** 
 * The result after a successful emit
 */
public struct EmitResult
{
    string createdFile;
    Duration elapsedTime;
    
    this(string createdFile, Duration elapsed)
    {
        this.createdFile = createdFile;
        this.elapsedTime = elapsed;
    }
}

import tlang.misc.exceptions : TError;
import std.string : format;

/** 
 * An error that occurs during
 * the code emitting process
 */
public class CodeEmitterException : TError
{
    this(string subSystem, string m)
    {
        super(subSystem, m);
    }

    this(string m)
    {
        this("code emit", m);
    }
}