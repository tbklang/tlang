/**
 * Enumerations support
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.compiler.symbols.typing.enums;

import tlang.compiler.symbols.data : Expression;
import tlang.compiler.symbols.typing.core : Type;
import niknaks.functional : Optional;

import tlang.misc.utils : panic;

public struct EnumConstant
{
    private string _n;
    private Expression _v;

    this(string name, Expression value)
    {
        this(name);
        this._v = value;
    }

    this(string name)
    {
        this._n = name;
    }

    public string name()
    {
        return this._n;
    }

    public Optional!(Expression) value()
    {
        return this._v is null ? Optional!(Expression).empty() : Optional!(Expression)(this._v);
    }
}

public final class Enum : Type
{
    private EnumConstant[] _m;
    private string _t;

    this(string name)
    {
        this(name, "");
    }

    this(string name, string constraintType)
    {
        super(name);
        this._t = constraintType;
    }

    public void add(EnumConstant c)
    {
        // TODO: In place do the oridinal filling here?
        this._m ~= c;
    }

    public void add(string member, Expression value)
    {
        add(EnumConstant(member, value));
    }

    // TODO: Do some const shit, don't want person to be
    // able to change this array
    public EnumConstant[] members()
    {
        return this._m;
    }

    public Optional!(string) getConstraint()
    {
        return this._t != null ? Optional!(string)(this._t) : Optional!(string).empty();
    }

    public override string toString()
    {
        import std.string : format;
        return format("Enum (%s)", getName());
    }
}

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.misc.logging;

private bool isValidExpression(Expression e)
{
    // TODO: Use templatung could be nice for long lists
    import std.meta : aliasSeqOf;
    
    
    import tlang.compiler.symbols.expressions : StringExpression, NumberLiteral, FloatingLiteral;

    return cast(StringExpression)e !is null || cast(NumberLiteral)e !is null;
}

import tlang.compiler.symbols.expressions : StringExpression, IntegerLiteral, FloatingLiteral;

private Type determineType(TypeChecker tc, Expression e)
{
    

    import tlang.compiler.symbols.typing.builtins : getBuiltInType;

    if(cast(StringExpression)e)
    {
        return getBuiltInType(null, null, "ubyte*");
    }
    else if(cast(IntegerLiteral)e)
    {
        IntegerLiteral il = cast(IntegerLiteral)e;
        return tc.determineLiteralEncodingType(il.getEncoding());
    }

    return null;
}

public void enumCheck(TypeChecker tc, Enum e, ref Type constraintOut)
{
    import tlang.compiler.symbols.data : Container;
    Container e_cntnr = e.parentOf();
    Optional!(string) ct_string = e.getConstraint();
    Type constraint = ct_string.isPresent() ? tc.getType(e_cntnr, ct_string.get()) : null;

    DEBUG("Beginning constraint (type):", constraint);

    foreach(c; e.members())
    {
        DEBUG("analyzing m:", c);
        Optional!(Expression) v_opt = c.value();
        Expression v_chosen;

        if(v_opt.isPresent())
        {
            v_chosen = v_opt.get();
        }
        else
        {
            // TODO: If no expression then base it 
        }

        Type m_type = determineType(tc, v_chosen);
        DEBUG("m_type:", m_type);

        if(constraint is null && m_type !is null)
        {
            constraint = m_type;
            DEBUG("constaint discovered via literal:", constraint);
        }
        else if(constraint !is null && m_type !is null)
        {

        }
        // If the `m_type` is null then it is because there is an unsupported
        // type (or null was given) but if `v_chosen` is NOT null then that
        // means an unsupported expression is being used
        else if(m_type is null && v_chosen !is null)
        {
            ERROR("We do not support enum constants to have expressions like '", v_chosen, "'");
            panic();
        }
    }

    // If constraint was never explicitly specified
    // or automatically discovered, then assume that
    // it is an integral type
    if(constraint is null)
    {
        import tlang.compiler.typecheck.literals.ranges : typeFromUnsignedRange;

        // Determine the type based on the number of
        // of members
        //
        // TODO: Document this fact as it is important
        // for the ABI
        Type type = typeFromUnsignedRange(e.members().length);
        assert(type);
        constraint = type;
    }

    DEBUG("constraint (type) decidedly:", constraint);
    constraintOut = constraint;
}

unittest
{
    string g = "";
    assert(g == null);
    assert(g == "");
    assert(g.ptr);

    g = null;
    assert(g == null);
    assert(g == "");

    assert(g.ptr);

}