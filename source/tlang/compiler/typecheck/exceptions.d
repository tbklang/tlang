module tlang.compiler.typecheck.exceptions;

import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import tlang.compiler.typecheck.resolution;
import std.string : cmp;
import std.conv : to;
import misc.exceptions: TError;
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

    this(TypeChecker typeChecker, TypecheckError errType, string msg = "")
    {
        /* We set it after each child class calls this constructor (which sets it to empty) */
        super("TypeCheck Error ("~to!(string)(errType)~")"~(msg.length > 0 ? ": "~msg : ""));
        this.typeChecker = typeChecker;
    }

    // TODO: Remove this constructor and make anything that is currently using it 
    // ... switch to atleast specifying the errType
    this(TypeChecker typeChecker)
    {
        this(typeChecker, TypecheckError.GENERAL_ERROR);
    }
}

public final class TypeMismatchException : TypeCheckerException
{
    this(TypeChecker typeChecker, Type originalType, Type attemptedType, string msgIn = "")
    {
        super(typeChecker);

        msg = "Type mismatch between type "~originalType.getName()~" and "~attemptedType.getName();

        msg ~= msgIn.length > 0 ? ": "~msgIn : "";
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
            string containerPath = typeChecker.getResolver().generateName(typeChecker.getModule(), defined);
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getModule(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as container \""~containerPath~"\"";
        }
        /* If colliding with root (Module) */
        else if(cmp(typeChecker.getModule().getName(), attempted.getName()) == 0)
        {
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getModule(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as module \""~typeChecker.getModule().getName()~"\"";
        }
        /* If colliding with a member within the container */
        else
        {
            string preExistingEntity = typeChecker.getResolver().generateName(typeChecker.getModule(), typeChecker.findPrecedence(c, attempted.getName()));
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getModule(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as entity \""~preExistingEntity~"\" within same container";
        }
    }

    public bool isCollidingWithContainer()
    {
        return attempted.parentOf() == defined;
    }

    
}