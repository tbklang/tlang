module tlang.compiler.symbols.expstmt;

import tlang.compiler.symbols.data : Statement;
import tlang.compiler.symbols.expressions : Expression;
import std.string : format;

// this is a non-expression, so, a normal statement
// that contains an expression
//
// Examples are:
// 1. standalone funciton calls
// 2. i++
public final class ExpressionStatement : Statement
{
    private Expression _e;
    this(Expression exp)
    {
        this._e = exp;

        /* Weighted like any other statement */
        this.weight = 2;
    }

    public Expression getExpression()
    {
        return this._e;
    }

    public override string toString()
    {
        return format("ExpressionStmt [e: %s]", _e);
    }
}