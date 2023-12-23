module tlang.compiler.typecheck.dependency.exceptions;

import misc.exceptions : TError;
import std.conv : to;

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

    public DependencyError getErrorType()
    {
        return errTye;
    }
}