module compiler.typecheck.exceptions;

import compiler.typecheck.core;
import compiler.symbols.data;
import compiler.typecheck.resolution;

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
    public Entity defined;

    /**
    * The colliding Entity
    */
    private Entity attempted;

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

        /* TODO: Set `msg` */
        /* TODO: (Gogga it) Generate the error message */
        if(isCollidingWithContainer())
        {
            string containerPath = typeChecker.getResolver().generateName(typeChecker.getModule(), defined);
            string entityPath = typeChecker.getResolver().generateName(typeChecker.getModule(), attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as container \""~containerPath~"\"";
        }
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