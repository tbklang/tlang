module compiler.symbols.containers;

import compiler.symbols.data;
import std.conv : to;
import compiler.symbols.typing.core;

/**
* Used so often that we may as well
* declare it once
*
* TODO: Check if we could do it with interfaces?
*/
private Statement[] weightReorder(Statement[] statements)
{
    import std.algorithm.sorting : sort;
    import std.algorithm.mutation : SwapStrategy;

    /* Re-ordered by lowest wieght first */
    Statement[] stmntsRed;

    /* Comparator for Statement objects */
    bool wCmp(Statement lhs, Statement rhs)
    {
        return lhs.weight < rhs.weight;
    }
    
    stmntsRed = sort!(wCmp, SwapStrategy.stable)(statements).release;

    return stmntsRed;
}

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
        return weightReorder(statements);
    }
}

/**
* Struct
*
* A Struct can only contain Entity's
* that are Variables (TODO: Enforce in parser)
* TODO: Possibly enforce here too
*/
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
        return weightReorder(statements);
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

        /* Weighted as 0 */
        weight = 0;
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
        return weightReorder(statements);
    }
    
}