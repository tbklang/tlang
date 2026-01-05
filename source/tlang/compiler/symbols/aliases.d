module tlang.compiler.symbols.aliases;

import tlang.compiler.symbols.data : Statement, Entity;
import tlang.compiler.symbols.expressions : Expression;
import std.string : format;
import tlang.compiler.symbols.mcro : MStatementSearchable, MStatementReplaceable;

// Debugging
import tlang.misc.logging;

/** 
 * A declaration of an alias expression
 */
public final class AliasDeclaration : Entity, MStatementSearchable, MStatementReplaceable
{
    // private string aliasName;
    private Expression aliasExpr;

    this(string aliasName, Expression aliasExpr)
    {
        // this.aliasName = aliasName;
        super(aliasName);
        this.aliasExpr = aliasExpr;
        this.weight = 2;
    }

    public Expression getExpr()
    {
        return this.aliasExpr;
    }

    public override string toString()
    {
        return format("Alias [name: %s, expr: %s]", getName(), this.aliasExpr);
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on expression */
        MStatementSearchable curStmtCasted = cast(MStatementSearchable)aliasExpr;
        if(curStmtCasted)
        {
            matches ~= curStmtCasted.search(clazzType);
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we, the `AliasDeclaration`, are the `thiz` then we cannot perform replacement */
        if(this == thiz)
        {
            return false;
        }
        /* Check if we should replace the `Expression` */
        else if(thiz == aliasExpr)
        {
            auto newAliasExpr = cast(Expression)that;
            if(newAliasExpr is null)
            {
                return false;
            }

            aliasExpr = newAliasExpr;
            DEBUG("aliasdecl(", getName() ,") replace: thiz=", thiz, "that=", that);
            assert(thiz.parentOf());
            DEBUG("that parent: ", that.parentOf());
            assert(aliasExpr.parentOf());
            return true;
        }
        /* Exhausted all possibilities */
        else
        {
            return false;
        }
    }
}