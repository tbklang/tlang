/**
 * Enumerations support
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
module tlang.compiler.symbols.typing.enums;

import tlang.compiler.symbols.data : Expression;
import tlang.compiler.symbols.typing.core : Type;
import niknaks.functional : Optional;

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
}

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.misc.logging;

public EnumConstant[] extractConstants(TypeChecker tc, Enum e)
{
    Optional!(string) ct_string = e.getConstraint();
    // Type constraint = 

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
            // TODO: Determine this here
        }
    }

    return null;
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