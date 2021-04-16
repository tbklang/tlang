module compiler.symbols.data;

import compiler.symbols.check;
import std.conv : to;


/**
* TODO: Implement the blow and use them
*
* These are just to use for keeping track of what
* valid identifiers are.
*
* Actually it might be, yeah it will
*/

public class Program
{
    private string moduleName;
    private Program[] importedModules;

    private Statement[] statements;

    this(string moduleName)
    {
        this.moduleName = moduleName;
    }

    public void addStatement(Statement statement)
    {
        statements ~= statement;
    }

    public static StatementType[] getAllOf(StatementType)(StatementType, Statement[] statements)
    {
        StatementType[] statementsMatched;

        foreach(Statement statement; statements)
        {
            /* TODO: Remove null, this is for unimpemented */
            if(statement !is null && cast(StatementType)statement)
            {
                statementsMatched ~= cast(StatementType)statement;
            }
        }

        return statementsMatched;
    }

    public Variable[] getGlobals()
    {
        Variable[] variables;

        foreach(Statement statement; statements)
        {
            if(typeid(statement) == typeid(Variable))
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    public Statement[] getStatements()
    {
        return statements;
    }
}

public class Statement
{
    private Container container;

    public final void parentTo(Container container)
    {
        this.container = container;
    }

    public final Container parentOf()
    {
        return container;
    }
}

public enum AccessorType
{
    PUBLIC, PRIVATE, PROTECTED, UNKNOWN
}

public enum FunctionType
{
    STATIC, VIRTUAL
}

public class Assignment : Statement
{
    private string identifier;
    private Expression assignmentExpression;

    this(string identifier, Expression assignmentExpression)
    {
        this.identifier = identifier;
        this.assignmentExpression = assignmentExpression;
    }
}

/* Declared variables, defined classes and fucntions */
public class Entity : Statement
{
    /* Accesor type */
    private AccessorType accessorType = AccessorType.PUBLIC;

    /* Function/Modifier type */
    private FunctionType functionType;

    /* Name of the entity (class's name, function's name, variable's name) */
    private string name;

    this(string name)
    {
        this.name = name;
    }

    public void setAccessorType(AccessorType accessorType)
    {
        this.accessorType = accessorType;
    }

    public AccessorType getAccessorType()
    {
        return accessorType;
    }

    public void setModifierType(FunctionType functionType)
    {
        this.functionType = functionType;
    }

    public FunctionType getModifierType()
    {
        return functionType;
    }

    public string getName()
    {
        return name;
    }
}

/* TODO: DO we need intermediary class, TypedEntity */
public class TypedEntity : Entity
{
    private string type;

    /* TODO: Return type/variable type in here (do what we did for ENtity with `name/identifier`) */
    this(string name, string type)
    {
        super(name);
        this.type = type;
    }

    public string getType()
    {
        return type;
    }
}

public class Container : Entity
{
    private Statement[] statements;

    this(string name)
    {
        super(name);
    }

    public void addStatement(Statement statement)
    {
        this.statements ~= statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.statements ~= statements;
    }

    public Statement[] getStatements()
    {
        return statements;
    }
}

public class Module : Container
{
    this(string moduleName)
    {
        super(moduleName);
    }
}

public class Clazz : Container
{
    private string[] interfacesClasses;

    this(string name)
    {
        super(name);
    }

    public void addInherit(string[] l)
    {
        interfacesClasses ~= l;
    }

    public string[] getInherit()
    {
        return interfacesClasses;
    }

    public override string toString()
    {
        return "Class (Name: "~name~", Parents (Class/Interfaces): "~to!(string)(interfacesClasses)~")";
    }
    
}

public class ArgumentList
{

}

public class Function : TypedEntity
{
    private Variable[] params;
    private Statement[] bodyStatements;

    this(string name, string returnType, Statement[] bodyStatements, Variable[] args)
    {
        super(name, returnType);
        this.bodyStatements = bodyStatements;
        this.params = args;
    }

    /**
    * This will sift through all the `Statement[]`'s in held
    * within this Function and will find those which are Variable
    */
    public Variable[] getVariables()
    {
        Variable[] variables;

        foreach(Statement statement; bodyStatements)
        {

            if(statement !is null && cast(Variable)statement)
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    public override string toString()
    {
        string argTypes;

        for(ulong i = 0; i < params.length; i++)
        {
            Variable variable = params[i];

            if(i == params.length-1)
            {
                argTypes ~= variable.getType();
            }
            else
            {
                argTypes ~= variable.getType() ~ ", ";
            }
        }
        
        return "Function (Name: "~name~", ReturnType: "~type~", Args: "~argTypes~")";
    }
}

public class Variable : TypedEntity
{
    /* TODO: Just make this an Expression */
    private VariableAssignment assignment;

    this(string type, string identifier)
    {
        super(identifier, type);
    }

    public void addAssignment(VariableAssignment assignment)
    {
        this.assignment = assignment;
    }

    public VariableAssignment getAssignment()
    {
        return assignment;
    }

    public override string toString()
    {
        return "Variable (Ident: "~name~", Type: "~type~")";
    }

    /* Code gen */
}


public import compiler.symbols.expressions;





public class VariableAssignment
{
    private Expression expression;

    this(Expression expression)
    {
        this.expression = expression;
    }

    public Expression getExpression()
    {
        return expression;
    }
}

public class IdentExpression : Expression
{
    /* name */
    private string name;

    this(string name)
    {
        this.name = name;
    }

    public string getName()
    {
        return name;
    }
}

public class VariableExpression : IdentExpression
{

    this(string identifier)
    {
        super(identifier);
    }

    import compiler.typecheck.core;
    public override string evaluateType(TypeChecker typeChecker, Container c)
    {
        string type;


        return null;
    }
}

public class Call : IdentExpression
{
    this(string ident)
    {
        super(ident);
    }
}

public final class FunctionCall : Call
{
    

    /* Argument list */
    private Expression[] arguments;

    this(string functionName, Expression[] arguments)
    {
        super(functionName);
        this.arguments = arguments;
    }
}