module compiler.symbols.expressions;

import compiler.symbols.data;

/* TODO: Look into arrays later */
public class StringExpression : Expression
{
    private string ztring;

    this(string ztring)
    {
        this.ztring = ztring;
    }
}

public class OperatorExpression : Expression
{
    /* Operator */
    private SymbolType operator;

    this(SymbolType operator)
    {
        this.operator = operator;
    }

    public SymbolType getOperator()
    {
        return operator;
    }
}

public class UnaryOperatorExpression : OperatorExpression
{
    private Expression exp;

    this(SymbolType operator, Expression exp)
    {
        super(operator);
        this.exp = exp;
    }
}

public class BinaryOperatorExpression : OperatorExpression
{
    private Expression lhs, rhs;

    /* TODO: Take in operator */
    this(SymbolType operator, Expression lhs, Expression rhs)
    {
        super(operator);
        this.lhs = lhs;
        this.rhs = rhs;
    }

    public Expression getLeftExpression()
    {
        return lhs;
    }

    public Expression getRightExpression()
    {
        return rhs;
    }
}

public class NumberLiteral : Expression
{
    private string numberLiteral;

    /* TODO: Take in info like tyoe */
    this(string numberLiteral)
    {
        this.numberLiteral = numberLiteral;
    }

    public override string toString()
    {
        return "[numberLiteral: "~numberLiteral~"]";
    }
}

public class Expression : Statement
{
    import compiler.typecheck.core;
    /* TODO: Takes in symbol table? */
    public string evaluateType(TypeChecker typechecker, Container c)
    {
        /* TODO: Go through here evaluating the type */

        return null;
    }

    this()
    {

    }

    /* TODO: Evalute this expression's type */
}

public final class NewExpression : Expression
{
    private FunctionCall funcCall;

    this(FunctionCall funcCall)
    {
        this.funcCall = funcCall;
    }

    public FunctionCall getFuncCall()
    {
        return funcCall;
    }
}