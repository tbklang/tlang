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

public class BinaryOperatorExpression : OperatorExpression, MStatementSearchable, MStatementReplaceable, MCloneable
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

    /** 
     * Clones this binery operator expression recursively
     * returning a fresh new copy of itself and its
     * left and right operands
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        BinaryOperatorExpression clonedBinaryOp;

        // Clone the left-hand operand expression (if supported, TODO: throw an error if not)
        Expression clonedLeftOperandExpression = null;
        if(cast(MCloneable)this.lhs)
        {
            MCloneable cloneableExpression = cast(MCloneable)this.lhs;
            clonedLeftOperandExpression = cast(Expression)cloneableExpression.clone(); // NOTE: We must parent it if needs be
        }

        // Clone the left-hand operand expression (if supported, TODO: throw an error if not)
        Expression clonedRightOperandExpression = null;
        if(cast(MCloneable)this.rhs)
        {
            MCloneable cloneableExpression = cast(MCloneable)this.rhs;
            clonedRightOperandExpression = cast(Expression)cloneableExpression.clone(); // NOTE: We must parent it if needs be
        }

        // Clone ourselves
        clonedBinaryOp = new BinaryOperatorExpression(this.operator, clonedLeftOperandExpression, clonedRightOperandExpression);

        // Parent outselves to the given parent
        clonedBinaryOp.parentTo(newParent);

        return clonedBinaryOp;
    }
}

public enum IntegerLiteralEncoding
{
    SIGNED_INTEGER,
    UNSIGNED_INTEGER,
    SIGNED_LONG,
    UNSIGNED_LONG
}

public class IntegerLiteral : NumberLiteral, MCloneable
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

    /** 
     * Clones this integer literal
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        IntegerLiteral clonedIntegerLiteral;

        clonedIntegerLiteral = new IntegerLiteral(this.numberLiteral, this.encoding);

        // Parent outselves to the given parent
        clonedIntegerLiteral.parentTo(newParent);

        return clonedIntegerLiteral;
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

public final class CastedExpression : Expression, MCloneable
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

    /** 
     * Clones this casted expression recursively
     * and returns a fresh copy of it
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        CastedExpression clonedCastedExpression;

        // Clone the uncasted expression (if supported, TODO: throw an error if not)
        Expression clonedUncastedExpression = null;
        if(cast(MCloneable)this.uncastedExpression)
        {
            MCloneable cloneableExpression = cast(MCloneable)this.uncastedExpression;
            clonedUncastedExpression = cast(Expression)cloneableExpression.clone(); // NOTE: We must parent it if needs be
        }

        clonedCastedExpression = new CastedExpression(this.toType, clonedUncastedExpression);

        // Parent outselves to the given parent
        clonedCastedExpression.parentTo(newParent);

        return clonedCastedExpression;
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

/** 
 * Represents an argument
 *
 * The reason for this to have
 * its own distinct AST node
 * type is because named parameters
 * require meta-data to be stored
 * alongside the actual argument
 * expression-value itself.
 */
public final class ArgumentNode : Expression
{
    private union ArgPos
    {
        string paramName;
        size_t paramPos;
    }

    private bool usingNamedParam;
    private ArgPos pos;
    private Expression value;

    private this
    (
        bool isNamedParameter,
        ArgPos pos,
        Expression value
    )
    {
        this.usingNamedParam = isNamedParameter;
        this.pos = pos;
        this.value = value;
    }

    public static ArgumentNode namedArgument(Expression expr, string paramName)
    {
        ArgPos p;
        p.paramName = paramName;
        return new ArgumentNode(true, p, expr);
    }

    public static ArgumentNode positionalArgument(Expression expr, size_t argPos)
    {
        ArgPos p;
        p.paramPos = argPos;
        return new ArgumentNode(false, p, expr);
    }

    public bool isNamedParameter()
    {
        return this.usingNamedParam;
    }

    public string getParamName()
    {
        assert(isNamedParameter());
        return pos.paramName;
    }

    public size_t getArgPos()
    {
        assert(!isNamedParameter());
        return pos.paramPos;
    }

    public Expression getExpr()
    {
        return this.value;
    }
}