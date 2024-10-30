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

version(unittest)
{
    import std.file;
    import std.stdio;
    import tlang.compiler.lexer.core;
    import tlang.compiler.lexer.kinds.basic : BasicLexer;
    import tlang.compiler.parsing.core;
    import tlang.compiler.core : Compiler;
    import tlang.compiler.typecheck.exceptions : CollidingNameException;
    import tlang.misc.exceptions : TError;
    import tlang.compiler.symbols.data : Module, Program, Entity;
    import tlang.compiler.typecheck.helpers.enums : EnumInfo;
}

public enum EnumErrorType
{
    UNSUPPORTED_VALUE_TYPE
}

public final class EnumError : Exception
{
    private EnumErrorType _t;

    private this(EnumErrorType e, string msg)
    {
        super(msg);
        this._t = e;
    }

    public static EnumError badValueType(string msg)
    {
        return new EnumError(EnumErrorType.UNSUPPORTED_VALUE_TYPE, msg);
    }

    public EnumErrorType getError()
    {
        return this._t;
    }
}

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

    /** 
     * Tries to find the member of
     * this enumeration type with
     * the given name
     *
     * Params:
     *   member = the member's 
     * name
     * Returns: an `Optional`
     * potentially containing
     * the name
     */
    public Optional!(EnumConstant) find(string member)
    {
        foreach(e; this._m)
        {
            if(e.name() == member)
            {
                return Optional!(EnumConstant)(e);
            }
        }
        return Optional!(EnumConstant).empty();
    }

    /** 
     * Returns the position that the given
     * enum constant occurs in
     *
     * Params:
     *   e = the `EnumConstant` to search
     * for
     * Returns: the index of the found
     * constant, otherwise `-`
     */
    public ptrdiff_t getPosition(EnumConstant e)
    {
        for(size_t i = 0; i < this._m.length; i++)
        {
            auto c = this._m[i];
            if(c.name() == e.name())
            {
                return i;
            }
        }
        return -1;
    }
}

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.misc.logging;

/** 
 * Checks if the provided expression
 * is one that is supported as an
 * enumeration type members' constant
 * value
 *
 * Params:
 *   e = the expression to check
 * Returns: `true` if so, `false`
 * otherwise
 */
public bool isValidExpression(Expression e)
{
    import tlang.compiler.symbols.expressions : StringExpression, NumberLiteral, FloatingLiteral;
    return cast(StringExpression)e !is null || cast(NumberLiteral)e !is null;
}

import tlang.compiler.symbols.expressions : StringExpression, IntegerLiteral, FloatingLiteral;

/** 
 * Given a certain expression this will
 * determine if it is a supported type
 * and if so return said type.
 *
 * Params:
 *   e = the `Expression` to check
 * Returns: a `Type` or `null` if it
 * is not a supported type
 */
private Type determineType(Expression e)
{
    import tlang.compiler.symbols.typing.builtins : getBuiltInType;
    assert(e);

    if(cast(StringExpression)e)
    {
        return getBuiltInType(null, null, "ubyte*");
    }
    else if(cast(IntegerLiteral)e)
    {
        IntegerLiteral il = cast(IntegerLiteral)e;
        return TypeChecker.determineLiteralEncodingType(il.getEncoding());
    }

    return null;
}

public Type getEnumType(TypeChecker tc, Enum e)
{
    Type type_o;
    enumCheck(tc, e, type_o);
    assert(type_o);
    return type_o;
}

import std.string : format;

private void enumCheck(TypeChecker tc, Enum e, ref Type constraintOut)
{
    import tlang.compiler.symbols.data : Container;
    Container e_cntnr = e.parentOf();
    Optional!(string) ct_string = e.getConstraint();
    Type constraint = ct_string.isPresent() ? tc.getType(e_cntnr, ct_string.get()) : null;

    // FIXME: Don'rt allowe specyifying types otgher than number and char*
    if(constraint !is null)
    {
        // TODO: Add check for string (char*)
        if(!(tc.isNumberType(constraint)))
        {
            throw EnumError.badValueType(format("An enum can only have a numerical or string explicit type, not a '%s'", constraint));
        }
    }

    DEBUG("Beginning constraint (type):", constraint);

    foreach(c; e.members())
    {
        DEBUG("analyzing m:", c);
        Optional!(Expression) v_opt = c.value();

        Type m_type = v_opt.isPresent() ? determineType(v_opt.get()) : null;
        DEBUG("m_type:", m_type);

        // if no explicit constraint but we have a supported
        // expression we can extract a type _from_
        if(constraint is null && m_type !is null)
        {
            constraint = m_type;
            DEBUG("constaint discovered via literal:", constraint);
        }
        // explicit constraint and we have extracted
        // a type from an expression that is present
        else if(constraint !is null && m_type !is null)
        {
            // both integral?
            if(tc.isIntegralType(constraint) && tc.isIntegralType(m_type))
            {
                // then check assignability of the `m_type`
                // to the `constraint` type
                import tlang.compiler.symbols.typing.core : Integer;
                if(!tc.isIntegralAssignableTo(cast(Integer)constraint, cast(Integer)m_type))
                {
                    throw EnumError.badValueType
                    (
                        format
                        (
                            "Cannot assign a value of type %s to an enum with explicit constraint type %s",
                            m_type,
                            constraint
                        )
                    );
                }
            }
            // else they must both be the same
            else if(!tc.isSameType(constraint, m_type))
            {
                throw EnumError.badValueType
                (
                    format
                    (
                        "Cannot assign a value of type %s to an enum with explicit constraint type %s",
                        m_type,
                        constraint
                    )
                );
            }
            
            // if we reach here, then we are fine
        }
        // If the `m_type` is null then it is because there is an unsupported
        // type (or null was given) but if `v_opt` is PRESENT then that
        // means an unsupported expression is being used
        else if(m_type is null && v_opt.isPresent())
        {
            throw EnumError.badValueType
            (
                format
                (
                    "We do not support enum constants to have expressions like '%s'",
                    v_opt.get()
                )
            );
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
    assert(constraintOut);
}


/** 
 * Test the parsing and then typechecking
 * facilities within this module that
 * deal with enumeration types
 *
 * In this case there are no errors that
 * would occur, therefore we will be
 * analyzing the parse tree
 */
unittest
{
    string sourceFile = "source/tlang/testing/enums/simple.t";

    File sourceFileFile;
    sourceFileFile.open(sourceFile);
    ulong fileSize = sourceFileFile.size();
    byte[] fileBytes;
    fileBytes.length = fileSize;
    fileBytes = sourceFileFile.rawRead(fileBytes);
    sourceFileFile.close();

    string sourceCode = cast(string) fileBytes;
    File dummyOut;
    Compiler compiler = new Compiler(sourceCode, sourceFile, dummyOut);

    compiler.doLex();
    compiler.doParse();

    /* Perform test */
    compiler.doTypeCheck();

    /* Extract our module */
    Program program = compiler.getProgram();
    TypeChecker typeChecker = compiler.getTypeChecker();
    Module modulle = program.getModules()[0];

    bool allEnum(Entity e_in)
    {
        return cast(Enum)e_in !is null;
    }
    Entity[] ent_out;
    typeChecker.getResolver().resolveWithin(modulle, &allEnum, ent_out);

    /* Get the enum info pool */
    auto ep = typeChecker.getEnumPool();

    /* There should be a total of 3 enum types */
    Enum[] enums = cast(Enum[])ent_out;
    assert(enums.length == 3);

    /* Scratchpad out variable */
    Type t_out;

    /* enum Sex */
    Enum sex_enum = enums[0];
    EnumConstant[] sex_constants = sex_enum.members();
    assert(sex_constants.length == 3);
    enumCheck(typeChecker, sex_enum, t_out);
    assert(t_out !is null);
    assert(t_out.getName() == "uint");
    EnumInfo sex_info = ep.pool(sex_enum);
    IntegerLiteral ec_expr_1 = cast(IntegerLiteral)sex_info.getExpressionFor(sex_constants[0]);
    assert(ec_expr_1);
    assert(ec_expr_1.getNumber() == "0");
    IntegerLiteral ec_expr_2 = cast(IntegerLiteral)sex_info.getExpressionFor(sex_constants[1]);
    assert(ec_expr_2);
    assert(ec_expr_2.getNumber() == "60");
    IntegerLiteral ec_expr_3 = cast(IntegerLiteral)sex_info.getExpressionFor(sex_constants[2]);
    assert(ec_expr_3);
    assert(ec_expr_3.getNumber() == "1");
    
    /* enum Gender */
    Enum gender_enum = enums[1];
    EnumConstant[] gender_constants = gender_enum.members();
    assert(gender_constants.length == 3);
    enumCheck(typeChecker, gender_enum, t_out);
    assert(t_out !is null);
    stderr.writeln(t_out);
    assert(t_out.getName() == "long");
    EnumInfo gender_info = ep.pool(gender_enum);
    ec_expr_1 = cast(IntegerLiteral)gender_info.getExpressionFor(gender_constants[0]);
    assert(ec_expr_1);
    assert(ec_expr_1.getNumber() == "0");
    ec_expr_2 = cast(IntegerLiteral)gender_info.getExpressionFor(gender_constants[1]);
    assert(ec_expr_2);
    assert(ec_expr_2.getNumber() == "2147483648");
    ec_expr_3 = cast(IntegerLiteral)gender_info.getExpressionFor(gender_constants[2]);
    assert(ec_expr_3);
    assert(ec_expr_3.getNumber() == "1");

    /* enum Numberless */
    Enum numberless_enum = enums[2];
    EnumConstant[] numberless_constants = numberless_enum.members();
    assert(numberless_constants.length == 2);
    enumCheck(typeChecker, numberless_enum, t_out);
    stderr.writeln(t_out);
    assert(t_out !is null);
    assert(t_out.getName() == "ubyte");
    EnumInfo numberless_info = ep.pool(numberless_enum);
    ec_expr_1 = cast(IntegerLiteral)numberless_info.getExpressionFor(numberless_constants[0]);
    assert(ec_expr_1);
    assert(ec_expr_1.getNumber() == "0");
    ec_expr_2 = cast(IntegerLiteral)numberless_info.getExpressionFor(numberless_constants[1]);
    assert(ec_expr_2);
    assert(ec_expr_2.getNumber() == "1");
}