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
    // NOTE: See if we use, as we seem to overwrite the `msg` value
    // ... in sub-classes of this
    public enum TypecheckError
    {
        GENERAL_ERROR,
        ENTITY_NOT_FOUND,
        ENTITY_NOT_DECLARED
    }

    private TypecheckError errType;

    this(TypeChecker typeChecker, TypecheckError errType, string msg = "")
    {
        /* We set it after each child class calls this constructor (which sets it to empty) */
        super("TypeCheck Error ("~to!(string)(errType)~")"~(msg.length > 0 ? ": "~msg : ""));
        this.errType = errType;
    }

    

    this(TypecheckError errType, string msg = "")
    {
        this(null, errType, msg);
    }

    public TypecheckError getError()
    {
        return errType;
    }
}

public final class TypeMismatchException : TypeCheckerException
{
    private Type originalType, attemptedType;

    private static string genMsg(Type o_type, Type a_type, string msgIn = "")
    {
        import std.string : format;
        return format
        (
            "Type mismatch between type %s and %s%s",
            o_type.getName(),
            a_type.getName(),
            msgIn.length > 0 ? ": "~msgIn : ""
        );
    }

    this(TypeChecker typeChecker, Type originalType, Type attemptedType, string msgIn = "")
    {
        super(TypecheckError.GENERAL_ERROR, genMsg(originalType, attemptedType));
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

    private static string genMsg(TypeChecker tc, Type t_type, Type f_type, string msgIn = "")
    {
        import std.string : format;
        import tlang.compiler.symbols.typing.enums : Enum, getEnumType;

        string t_type_s = t_type.getName(); // to-type
        string f_type_s = f_type.getName(); // from-type

        /* Lookup enum's component type */
        if(TypeChecker.isEnumType(f_type))
        {
            Type e_type = getEnumType(tc, cast(Enum)f_type);
            f_type_s = format("%s[%s]", f_type.getName(), e_type.getName());
        }
        
        return format
        (
            "Cannot coerce from type '%s' to type '%s'%s",
            f_type_s,
            t_type_s,
            msgIn.length > 0 ? ": "~msgIn : ""
        );
    }

    this(TypeChecker tc, Type toType, Type fromType, string msgIn = "")
    {
        super(TypecheckError.GENERAL_ERROR, genMsg(tc, toType, fromType, msgIn));
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

    private static string genMsg
    (
        TypeChecker tc,
        Entity defined,
        Entity attempted,
        Container c
    )
    {
        import std.string : format;
        
        /* If colliding with the container */
        if(attempted.parentOf() == defined)
        {
            string containerPath = tc.getResolver().generateName(tc.getProgram(), defined);
            string entityPath = tc.getResolver().generateName(tc.getProgram(), attempted);
            return "Cannot have entity \""~entityPath~"\" with same name as container \""~containerPath~"\"";
            return format
            (
                "Cannot have entity \"%s\" with same name as container \"%s\"",
                entityPath,
                containerPath
            );
        }
        /* If colliding with a one of the program's modules */
        else if(isCollidingWithAModule(tc, attempted))
        {
            string entityPath = tc.getResolver().generateName(tc.getProgram(), attempted);
            return format
            (
                "Cannot have entity \"%s\" with same name as module \"%s\"",
                entityPath,
                getCollidedModule(tc, attempted).getName()
            );
        }
        /* If colliding with a member within the container */
        else
        {
            string preExistingEntity = tc.getResolver().generateName(tc.getProgram(), tc.findPrecedence(c, attempted.getName()));
            string entityPath = tc.getResolver().generateName(tc.getProgram(), attempted);
            return format
            (
                "Cannot have entity \"%s\" with same name as entity \"%s\" within same container",
                entityPath,
                preExistingEntity
            );
        }
    }

    private static bool isCollidingWithAModule(TypeChecker tc, Entity attempted)
    {
        return getCollidedModule(tc, attempted) !is null;
    }

    private static Module getCollidedModule(TypeChecker tc, Entity attempted)
    {
        Program program = tc.getProgram();
        foreach(Module curMod; program.getModules())
        {
            if(cmp(attempted.getName(), curMod.getName()) == 0)
            {
                return curMod;
            }
        }

        return null;
    }

    this(TypeChecker typeChecker, Entity defined, Entity attempted, Container c)
    {
        super(TypecheckError.GENERAL_ERROR, genMsg(typeChecker, defined, attempted, c));
        this.defined = defined;
        this.attempted = attempted;
        this.c = c;        
    }
}