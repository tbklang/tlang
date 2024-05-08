module tlang.compiler.symbols.aliases;

import tlang.compiler.symbols.data : Statement;
import tlang.compiler.symbols.expressions : Expression;
import std.string : format;

/** 
 * A declaration of an alias expression
 */
public final class AliasDeclaration : Statement
{
    private string aliasName;
    private Expression aliasExpr;

    this(string aliasName, Expression aliasExpr)
    {
        this.aliasName = aliasName;
        this.aliasExpr = aliasExpr;
    }

    public string getName()
    {
        return this.aliasName;
    }

    public Expression getExpr()
    {
        return this.aliasExpr;
    }

    public override string toString()
    {
        return format("Alias [name: %s]", this.aliasName);
    }
}