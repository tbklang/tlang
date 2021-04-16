module compiler.symbols.containers;

import compiler.symbols.data;
import std.conv : to;

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