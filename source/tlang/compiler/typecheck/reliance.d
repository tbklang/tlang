module compiler.typecheck.reliance;

import compiler.symbols.data;

/**
* RelianceNode
*
* Represents a node in a tree saying which node
* depends on what
*/
public final class RelianceNode
{
    /* The Statement associated */
    private Statement statement;

    /* Depends on */
    private RelianceNode[] dependancies;

    /**
    * Creates a new RelianceNode with the
    * associated Statement
    */
    this(Statement statement)
    {
        this.statement = statement;
    }

    public void addDependancy(RelianceNode dependency)
    {
        dependancies ~= dependency;
    }

    public RelianceNode[] getDependencies()
    {
        return dependancies;
    }

    public Statement getStatement()
    {
        return statement;
    }
}