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
        GENERAL_ERROR,
        ENTITY_NOT_FOUND,
        ENTITY_NOT_DECLARED,

        NOT_MEMBER_OF_TYPE,
        CYCLE_DETECTED
    }

    private TypecheckError errType;

    this(TypeChecker typeChecker, TypecheckError errType, string msg = "")
    {
        /* We set it after each child class calls this constructor (which sets it to empty) */
        super("TypeCheck Error ("~to!(string)(errType)~")"~(msg.length > 0 ? ": "~msg : ""));
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

        msg = "Type mismatch between type "~originalType.getName()~" and "~attemptedType.getName();

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

public final class CoercionException : TypeCheckerException
{
    private Type toType, fromType;

    this(TypeChecker typeChecker, Type toType, Type fromType, string msgIn = "")
    {
        super(typeChecker);

        msg = "Cannot coerce from type '"~fromType.getName()~"' to type '"~toType.getName()~"'";

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
            string containerPath = typeChecker.getResolver().generateName(typeChecker.getProgram(), defined);
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getProgram(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as container \""~containerPath~"\"";
        }
        /* If colliding with a one of the program's modules */
        else if(isCollidingWithAModule())
        {
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getProgram(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as module \""~getCollidedModule().getName()~"\"";
        }
        /* If colliding with a member within the container */
        else
        {
            string preExistingEntity = typeChecker.getResolver().generateName(typeChecker.getProgram(), typeChecker.findPrecedence(c, attempted.getName()));
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getProgram(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as entity \""~preExistingEntity~"\" within same container";
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