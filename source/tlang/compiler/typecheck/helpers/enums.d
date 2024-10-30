module tlang.compiler.typecheck.helpers.enums;

import tlang.compiler.typecheck.core : TypeChecker;

import tlang.compiler.symbols.typing.enums : isValidExpression, Enum, EnumConstant;
import tlang.compiler.symbols.expressions : Expression;
import tlang.compiler.symbols.expressions : StringExpression, NumberLiteral, FloatingLiteral, IntegerLiteral;

import tlang.compiler.codegen.instruction : Value, LiteralValue;

import tlang.misc.utils : panic;
import tlang.misc.logging;

import niknaks.functional : Optional;

public Value fromExpression(TypeChecker tc, Expression e)
{
    assert(isValidExpression(e));

    if(cast(StringExpression)e)
    {
        panic("Todo, add StrExpr -> ValueInstr support");
    }
    else if(cast(FloatingLiteral)e)
    {
        panic("Todo, add FloatExpr -> ValueInstr support");
    }
    else
    {
        IntegerLiteral li = cast(IntegerLiteral)e;
        auto lv_t = tc.determineLiteralEncodingType(li.getEncoding());
        LiteralValue lv = new LiteralValue(li.getNumber(), lv_t);
        return lv;
    }
}

/** 
 * Generates a `Value`-based instruction
 * corresponding to the enum constant
 * being referenced
 *
 * Params:
 *   tc = the `TyepChecker` instance
 *   e = the `Enum`
 *   ec = the enum's member being
 * referenced
 *   flatten = whether or not to generate
 * a flat instruction. If this is `true`
 * then an `EnumConstantRef` instruction
 * will NOT be generated.
 * Returns: a `Value`-based instruction
 */
public Value enumConstantToInstruction
(
    TypeChecker tc,
    Enum e,
    EnumConstant ec,
    bool flatten = true
)
{
    Optional!(Expression) ec_v_opt = ec.value();

    Value v_instr;
    if(ec_v_opt.isPresent())
    {
        v_instr = fromExpression(tc, ec_v_opt.get());
    }
    else
    {
        v_instr = fromExpression(tc, getOrdinal(tc, e, ec));
    }

    if(!flatten)
    {
        import tlang.compiler.codegen.instruction : EnumConstantRef;
        v_instr = new EnumConstantRef(e, ec.name());
    }

    v_instr.setInstrType(e);
    return v_instr;
}

public Expression getOrdinal(TypeChecker tc, Enum e, EnumConstant ec)
{
    auto ds = tc.getEnumPool();
    EnumInfo ei = ds.pool(e);
    return ei.getExpressionFor(ec);
}

import niknaks.containers : Pool;

public final class EnumInfo
{
    private Enum _e;
    private Expression[EnumConstant] _v;
    this(Enum e)
    {
        this._e = e;
        init();
    }

    public Expression getExpressionFor(EnumConstant ec)
    {
        Expression* expr = ec in this._v;
        assert(expr); // should be calling it with the same EnumConstant(s) that came in
        return *expr;
    }

    private void init()
    {
        // TODO: Step 1: Perform the ordinal determination

        // first save all constants which have
        // explicit values
        foreach(m; _e.members())
        {
            Optional!(Expression) v_opt = m.value();
            if(v_opt.isEmpty())
            {
                continue;
            }

            auto expr = v_opt.get();
            this._v[m] = expr;
            DEBUG("(First run) Stored explicit expr '", expr, "' for member '", m.name(), "'");
        }

        // now fill in all the other values
        // m: pivot member
        foreach(m; _e.members())
        {
            Expression* sc = m in this._v;
            DEBUG("m:", m);

            // skip entries with explicit values
            if(sc !is null)
            {
                DEBUG("(Second run) Skipping explicit value '", m, "'");
                continue;
            }
            
            // Keep looping till we generate enough (TODO: Odd case of infinite loop on huge enum?)
            Expression g_expr = getInitVal(); // TODO: Change for non-integral literals?
            while(isExpressionPresent(g_expr))
            {
                // DEBUG("Loop");
                g_expr = nextIntegral(cast(IntegerLiteral)g_expr);
                DEBUG("generated next:", g_expr);
            }
            
            // Store free-value
            this._v[m] = g_expr;
            DEBUG("Found unused value:", g_expr);
        }

        DEBUG("Determined all values:", this._v);
    }

    private bool isExpressionPresent(Expression e)
    {
        foreach(c; this._v.values())
        {
            auto cmp = compareExpr(c, e);
            DEBUG("<<<<<<<>>>>>>>");
            DEBUG("cmp:", cmp);
            DEBUG("<<<<<<<>>>>>>>");
            if(cmp == 0)
            {
                DEBUG("d");
                return true;
            }
        }
        return false;
    }
}

import tlang.compiler.symbols.expressions : IntegerLiteralEncoding;
import std.conv : to;

private Expression getInitVal()
{
    return new IntegerLiteral("0", IntegerLiteralEncoding.UNSIGNED_INTEGER);
}

private IntegerLiteral nextIntegral(IntegerLiteral li_in)
{
    auto lit_str = li_in.getNumber();
    auto lit_enc = li_in.getEncoding();

    string lit_str_out;

    if(IntegerLiteral.isSignedEncoding(lit_enc))
    {
        long lit_val = cast(long)to!(ulong)(lit_str);
        lit_str_out = to!(string)(lit_val+1);
    }
    else
    {
        ulong lit_val = to!(ulong)(lit_str);
        lit_str_out = to!(string)(lit_val+1);
    }

    return new IntegerLiteral(lit_str_out, lit_enc);
}

private ptrdiff_t compareExpr(Expression l, Expression r)
{
    IntegerLiteral il_e_left = cast(IntegerLiteral)l;
    IntegerLiteral il_e_right = cast(IntegerLiteral)r;

    DEBUG("il_e_left:", il_e_left);
    DEBUG("il_e_right:", il_e_right);

    if(il_e_left && il_e_right)
    {
        auto e = il_e_left.getEncoding();
        DEBUG("e:", e);

        // todo, what about cases where the encodings differ?
        if(IntegerLiteral.isSignedEncoding(il_e_left.getEncoding()))
        {

        }

        if(e == IntegerLiteralEncoding.UNSIGNED_INTEGER)
        {
            DEBUG("f");
            il_e_left.getNumber();
        }    
    }
    
    // todo: remove, this is just for testing now
    return to!(ulong)(il_e_left.getNumber()) - to!(ulong)(il_e_right.getNumber());
    // return 0;
}