module compiler.typecheck.exceptions;

import compiler.typecheck.core;
import compiler.symbols.data;

public class TypeCheckerException : Exception
{
    private TypeChecker typeChecker;

    this(TypeChecker typeChecker)
    {
        /* We set it after each child class calls this constructor (which sets it to empty) */
        super("");
        this.typeChecker = typeChecker;
    }
}

public final class CollidingNameException : TypeCheckerException
{
    /**
    * The previously declared Entity
    */
    private Entity defined;

    /**
    * The colliding Entity
    */
    private Entity attempted;

    this(TypeChecker typeChecker, Entity defined, Entity attempted)
    {
        super(typeChecker);

        this.defined = defined;
        this.attempted = attempted;

        /* TODO: Set `msg` */
        /* TODO: (Gogga it) Generate the error message */
    }

    public bool isCollidingWithContainer()
    {
        return attempted.parentOf() == defined;
    }

    
}