module compiler.symbols.containers;

import compiler.symbols.data;
import std.conv : to;
import compiler.symbols.typing;

public interface Container
{
    public void addStatement(Statement statement);

    public void addStatements(Statement[] statements);

    public Statement[] getStatements();
}

public class Module : Entity, Container
{
    this(string moduleName)
    {
        super(moduleName);
    }

    private Statement[] statements;


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

public class Struct : Type, Container
{
    private Statement[] statements;

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

    this(string name)
    {
        super(name);
    }
}

public class Clazz : Type, Container
{
    private Statement[] statements;

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