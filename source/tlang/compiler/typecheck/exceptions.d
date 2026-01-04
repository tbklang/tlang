module tlang.compiler.typecheck.exceptions;

import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import tlang.compiler.typecheck.resolution;
import std.string : cmp;
import std.conv : to;
import tlang.misc.exceptions: TError;
import tlang.compiler.symbols.typing.core;

public class TypeCheckerException : TError
{
    private TypeChecker typeChecker;

    // NOTE: See if we use, as we seem to overwrite the `msg` value
    // ... in sub-classes of this
    public enum TypecheckError
    {
        GENERAL_ERROR
    }

    private TypecheckError errType;

    this(TypeChecker typeChecker, TypecheckError errType, string msg = "")
    {
        /* We set it after each child class calls this constructor (which sets it to empty) */
        super("typecheck", "TypeCheck Error ("~to!(string)(errType)~")"~(msg.length > 0 ? ": "~msg : ""));
        this.typeChecker = typeChecker;
        this.errType = errType;
    }

    // TODO: Remove this constructor and make anything that is currently using it 
    // ... switch to atleast specifying the errType
    this(TypeChecker typeChecker)
    {
        this(typeChecker, TypecheckError.GENERAL_ERROR);
    }

    public TypecheckError getError()
    {
        return errType;
    }
}

public final class TypeMismatchException : TypeCheckerException
{
    private Type originalType, attemptedType;

    this(TypeChecker typeChecker, Type originalType, Type attemptedType, string msgIn = "")
    {
        super(typeChecker);

        msg = makeMessage("Type mismatch between type", originalType, "and", attemptedType);

        msg ~= msgIn.length > 0 ? ": "~msgIn : "";

        this.originalType = originalType;
        this.attemptedType = attemptedType;
    }

    public Type getExpectedType()
    {
        return originalType;
    }

    public Type getAttemptedType()
    {
        return attemptedType;
    }
}

import tlang.misc.messaging : makeMessage;

public final class CoercionException : TypeCheckerException
{
    private Type toType, fromType;

    this(TypeChecker typeChecker, Type toType, Type fromType, string msgIn = "")
    {
        super(typeChecker);

        msg = makeMessage("Cannot coerce from", fromType, "to", toType);

        msg ~= msgIn.length > 0 ? ": "~msgIn : "";

        this.toType = toType;
        this.fromType = fromType;
    }

    public Type getToType()
    {
        return toType;
    }

    public Type getFromType()
    {
        return fromType;
    }
}

public final class CollidingNameException : TypeCheckerException
{
    /**
    * The previously declared Entity
    */
    public Entity defined;

    /**
    * The colliding Entity
    */
    public Entity attempted;

    /**
    * The Container we are in
    */
    private Container c;

    this(TypeChecker typeChecker, Entity defined, Entity attempted, Container c)
    {
        super(typeChecker);

        this.defined = defined;
        this.attempted = attempted;
        this.c = c;

        /* If colliding with the container */
        if(isCollidingWithContainer())
        {
            msg = makeMessage("Cannot have entity", attempted, "with same name as container", c);
        }
        /* If colliding with a one of the program's modules */
        else if(isCollidingWithAModule())
        {
            msg = makeMessage("Cannot have entity", attempted, "with same name as module", getCollidedModule());
        }
        /* If colliding with a member within the container */
        else
        {
            msg = makeMessage("Cannot have entity", attempted, "with same name as entity", defined, "within same container");
        }
    }

    public bool isCollidingWithContainer()
    {
        return attempted.parentOf() == defined;
    }

    private bool isCollidingWithAModule()
    {
        return getCollidedModule() !is null;
    }

    private Module getCollidedModule()
    {
        Program program = this.typeChecker.getProgram();
        foreach(Module curMod; program.getModules())
        {
            if(cmp(attempted.getName(), curMod.getName()) == 0)
            {
                return curMod;
            }
        }

        return null;
    }
}