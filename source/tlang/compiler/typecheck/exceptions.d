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
        if(isCollidingWithContainer())
        {
            string containerPath = typeChecker.getResolver().generateName(modulle, defined);
            string entityPath = typeChecker.getResolver().generateName(modulle, attempted);
            msg = "Cannot have entity \""~entityPath~"\" with same name as container \""~containerPath~"\"";
        }
        else
        {
            string preExistingEntity = resolver.generateName(modulle, findPrecedence(c, entity.getName()));
            string entityPath = resolver.generateName(modulle, entity);
            msg = "Cannot have entity \""~entityPath~"\" with same name as entity \""~preExistingEntity~"\" within same container";
        }
    }

    public bool isCollidingWithContainer()
    {
        return attempted.parentOf() == defined;
    }

    
}