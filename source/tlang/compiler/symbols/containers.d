module compiler.symbols.containers;

import compiler.symbols.data;
import std.conv : to;
import compiler.symbols.typing.core;

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
         /* Re-ordered by lowest wieght first */
        Statement[] stmntsRed;

        bool wCmp(Statement lhs, Statement rhs)
        {
            return lhs.weight < rhs.weight;
        }
        import std.algorithm.sorting;
        stmntsRed = sort!(wCmp)(statements).release;
    

        return stmntsRed;
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
         /* Re-ordered by lowest wieght first */
        Statement[] stmntsRed;

        bool wCmp(Statement lhs, Statement rhs)
        {
            return lhs.weight < rhs.weight;
        }
        import std.algorithm.sorting;
        stmntsRed = sort!(wCmp)(statements).release;
    

        return stmntsRed;
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
         /* Re-ordered by lowest wieght first */
        Statement[] stmntsRed;

        bool wCmp(Statement lhs, Statement rhs)
        {
            return lhs.weight < rhs.weight;
        }
        import std.algorithm.sorting;
        stmntsRed = sort!(wCmp)(statements).release;
    

        return stmntsRed;
    }
    
}