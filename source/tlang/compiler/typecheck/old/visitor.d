module compiler.typecheck.visitor;

import compiler.symbols.data;

public final class VisitorTree
{
    private VTreeNode root;

    this(VTreeNode root)
    {
        this.root = root;
    }
}

public final class VTreeNode
{
    private VTreeNode[] children;
    private Statement statement;

    this(Statement statement)
    {
        this.statement = statement;
    }

    public void addChild(VTreeNode newChild)
    {
        children ~= newChild;
    }

    public Statement getStatement()
    {
        return statement;
    }

    public VTreeNode[] getChildren()
    {
        return children;
    }

    public VTreeNode isInTree(Statement statement)
    {
        /* If this node is the one being searched for */
        if(this.getStatement() == statement)
        {
            return this;
        }
        /* If not */
        else
        {
            /* Get all this node's children */
            VTreeNode[] children = this.getChildren();

            /* Make sure there are children */
            if(children.length)
            {   
                /* Any of the children */
                foreach(VTreeNode child; children)
                {
                    if(child.isInTree(statement))
                    {
                        return child;
                    }
                }

                /* If above fails, then not found */
                return null;
            }
            /* If there are no children then not found */
            else
            {
                return null;
            }
        }
    }
}