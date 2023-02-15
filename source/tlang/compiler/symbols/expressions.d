module tlang.compiler.symbols.expressions;

import tlang.compiler.symbols.data;
import std.conv : to;

/* TODO: Look into arrays later */
public class StringExpression : Expression
{
    private string ztring;

    this(string ztring)
    {
        this.ztring = ztring;
    }

    public string getStringLiteral()
    {
        return ztring;
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

    public override string toString()
    {
        return "[unaryOperator: Op: "~to!(string)(operator)~", Expr: "~to!(string)(exp);
    }

    public Expression getExpression()
    {
        return exp;
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

    public override string toString()
    {
        /* TODO: FIll in */
        return "[BinOpExp: Op: "~to!(string)(operator)~", Lhs: "~lhs.toString()~", Rhs: "~rhs.toString()~"]";
    }
}

public enum IntegerLiteralEncoding
{
    SIGNED_INTEGER,
    UNSIGNED_INTEGER,
    SIGNED_LONG,
    UNSIGNED_LONG
}

public final class IntegerLiteral : NumberLiteral
{
    private IntegerLiteralEncoding encoding;

    this(string integerLiteral, IntegerLiteralEncoding encoding)
    {
        super(integerLiteral);
        this.encoding = encoding;
    }

    public IntegerLiteralEncoding getEncoding()
    {
        return encoding;
    }

    public override string toString()
    {
        return "[integerLiteral: "~numberLiteral~" ("~to!(string)(encoding)~")]";
    }
}

//TODO: Work on floating point literal encodings
public final class FloatingLiteral : NumberLiteral
{
    // TODO: Put the equivalent of FloatingLiteralEncoding here

    this(string floatingLiteral)
    {
        super(floatingLiteral);
    }

    public override string toString()
    {
        return "[floatingLiteral: "~numberLiteral~"]"; // ("~to!(string)(encoding)~")]";
    }
}

public abstract class NumberLiteral : Expression
{
    private string numberLiteral;

    this(string numberLiteral)
    {
        this.numberLiteral = numberLiteral;
    }

    public final string getNumber()
    {
        return numberLiteral;
    }
}

public class Expression : Statement
{
    import tlang.compiler.typecheck.core;
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

public final class CastedExpression : Expression
{
    private Expression uncastedExpression;
    private string toType;

    this(string toType, Expression uncastedExpression)
    {
        this.toType = toType;
        this.uncastedExpression = uncastedExpression;
    }

    public string getToType()
    {
        return toType;
    }

    public Expression getEmbeddedExpression()
    {
        return uncastedExpression;
    }
}

public final class ArrayIndex : Expression
{
    /* The expression to index of */
    private Expression indexInto;

    /* The expression used as the index */
    private Expression index;

    this(Expression indexInto, Expression index)
    {
        this.indexInto = indexInto;
        this.index = index;
    }

    public Expression getIndexed()
    {
        return indexInto;
    }

    public Expression getIndex()
    {
        return index;
    }

    public override string toString()
    {
        return "ArrayIndex [to: "~indexInto.toString()~", idx: "~index.toString()~"]";
    }
}