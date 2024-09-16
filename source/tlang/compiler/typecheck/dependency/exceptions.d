module tlang.compiler.typecheck.dependency.exceptions;

import tlang.misc.exceptions : TError;
import std.conv : to;
import std.string : format;

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

/** 
 * An access violation occurs when you
 * try to access one entity from an
 * environment that doesn't allow
 * for that due to the access rights
 * of the referent entity
 */
public final class AccessViolation : TError
{
    import tlang.compiler.symbols.data : Entity, Statement;

    this
    (
        Statement env,
        Entity referent
    )
    {
        super
        (
            format
            (
                "Cannot access entity '%s' with access modifier %s from statement '%s'",
                referent.getName(),
                referent.getAccessorType(),
                env
            )
        );
    }
}