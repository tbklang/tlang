module compiler.typecheck.exceptions;

import compiler.typecheck.core;
import compiler.symbols.data;
import compiler.typecheck.resolution;
import std.string : cmp;

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