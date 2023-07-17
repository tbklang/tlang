module tlang.compiler.symbols.expressions;

import tlang.compiler.symbols.data;
import std.conv : to;

// AST manipulation interfaces
import tlang.compiler.symbols.mcro : MStatementSearchable, MStatementReplaceable, MCloneable;

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

public class BinaryOperatorExpression : OperatorExpression, MStatementSearchable, MStatementReplaceable
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

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on our left-hand side `Expression` (if possible) */
        MStatementSearchable lhsCasted = cast(MStatementSearchable)lhs;
        if(lhsCasted)
        {
            matches ~= lhsCasted.search(clazzType); 
        }

        /* Recurse on our right-hand side `Expression` (if possible) */
        MStatementSearchable rhsCasted = cast(MStatementSearchable)rhs;
        if(rhsCasted)
        {
            matches ~= rhsCasted.search(clazzType); 
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* We cannot directly replace ourselves */
        if(this == thiz)
        {
            return false;
        }
        /* Is the left-hand side `Expression` to be replaced? */
        else if(thiz == lhs)
        {
            lhs = cast(Expression)that;
            return true;
        }
        /* Is the right-hand side `Expression` to be replaced? */
        else if(thiz == rhs)
        {
            rhs = cast(Expression)that;
            return true;
        }
        /* If not direct match, then recurse and replace on left-hand side `Expression` (if possible) */
        else if(cast(MStatementReplaceable)lhs)
        {
            MStatementReplaceable lhsCasted = cast(MStatementReplaceable)lhs;
            return lhsCasted.replace(thiz, that);
        }
        /* If not direct match, then recurse and replace on right-hand side `Expression` (if possible) */
        else if(cast(MStatementReplaceable)rhs)
        {
            MStatementReplaceable rhsCasted = cast(MStatementReplaceable)rhs;
            return rhsCasted.replace(thiz, that);
        }
        /* If not direct match and not replaceable */
        else
        {
            return false;
        }
    }
}

public enum IntegerLiteralEncoding
{
    SIGNED_INTEGER,
    UNSIGNED_INTEGER,
    SIGNED_LONG,
    UNSIGNED_LONG
}

public class IntegerLiteral : NumberLiteral
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

    public final void setNumber(string numberLiteral)
    {
        this.numberLiteral = numberLiteral;
    }
}

public abstract class Expression : Statement
{
    
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