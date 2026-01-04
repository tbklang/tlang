module tlang.compiler.typecheck.dependency.exceptions;

import tlang.misc.exceptions : TError;
import std.conv : to;

import tlang.misc.messaging : makeMessage;

// FIXME: Extend TError rather than Exception
public enum DependencyError
{
    NOT_YET_LINEARIZED,
    ALREADY_LINEARIZED,
    GENERAL_ERROR
}

public final class DependencyException : TError
{
    private DependencyError errTye;

    this(DependencyError errTye, string occuring = __FUNCTION__)
    {
        super("DependencyException("~occuring~"): We got a "~to!(string)(errTye));
        this.errTye = errTye;
    }

    this(string m)
    {
        super("depgen", m);
    }

    this(T...)(T args)
    {
        this(makeMessage(args));
    }

    public DependencyError getErrorType()
    {
        return errTye;
    }
}