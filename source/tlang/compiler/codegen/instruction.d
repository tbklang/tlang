module tlang.compiler.codegen.instruction;

import std.conv : to;
import tlang.compiler.typecheck.dependency.core : Context;
import std.string : cmp, format;
import tlang.compiler.symbols.data : SymbolType;
import tlang.compiler.symbols.check : getCharacter;
import gogga;
import tlang.compiler.symbols.typing.core : Type;
import tlang.misc.logging;
import tlang.compiler.codegen.render;

public abstract class Instruction
{
    /* Context for the Instruction (used in emitter for name resolution) */
    private Context context; //TODO: Make this private and add a setCOntext

    protected string addInfo;

    public override string toString()
    {
        return "[Instruction: "~this.classinfo.name~":"~addInfo~"]";
    }

    private final string produceToStrEnclose(string addInfo)
    {
        return "[Instruction: "~this.classinfo.name~":"~addInfo~"]";
    }

    public final Context getContext()
    {
        return context;
    }

    public final void setContext(Context context)
    {
        this.context = context;
    }
}

public class Value : Instruction
{
    /* The type of the Value this instruction produces */
    private Type type;

    public final void setInstrType(Type type)
    {
        this.type = type;
    }

    public final Type getInstrType()
    {
        return type;
    }
}

/** 
 * This represents any instruction
 * which has a string-based target
 * that may be manipulated
 */
public interface Targetable
{
    /** 
     * Retrieve's the target
     *
     * Returns: the target
     */
    public string getTarget();

    /** 
     * Sets the target
     *
     * Params:
     *   target = the target
     */
    public void setTarget(string target);
}

public class StorageDeclaration : Instruction
{

}

public class ClassStaticInitAllocate : Instruction
{
    this(string className)
    {
        addInfo = "classStaticInitAllocate: "~className;
    }
}

public class VariableAssignmentInstr : Instruction, IRenderable
{
    /* Name of variable being declared */
    private string varName;

    /* Assigmment data */
    private Value data;

    this(string varName, Value data)
    {
        this.varName = varName;
        this.data = data;

        addInfo = "assignTo: "~varName~", valInstr: "~data.toString();
    }

    public string getTarget()
    {
        return this.varName;
    }

    public Value getAssignmentValue()
    {
        return this.data;
    }

    public string render()
    {
        return format("%s = %s", varName, tryRender(data));
    }
}

public final class VariableDeclaration : StorageDeclaration, IRenderable
{
    /* Name of variable being declared */
    private string varName;

    /* Length */
    public const byte length;

    /* Type of the variable being declared */
    private Type varType;

    /* Value-instruction to be assigned */
    private Value varAssInstr;

    //TODO: This must take in type information
    this(string varName, byte len, Type varType, Value varAssInstr)
    {
        this.varName = varName;
        this.length = len;
        this.varType = varType;

        this.varAssInstr = varAssInstr;

        addInfo = "varName: "~varName;
    }

    public Value getAssignmentInstr()
    {
        return varAssInstr;
    }

    public bool hasAssignmentInstr()
    {
        return varAssInstr !is null;
    }

    public string getTarget()
    {
        return this.varName;
    }

    public Type getType()
    {
        return this.varType;
    }

    public string render()
    {
        string varAssInstr_s = hasAssignmentInstr() ? format(" = %s", tryRender(getAssignmentInstr())) : "";
        return format("%s %s%s", varType.getName(), varName, varAssInstr_s);
    }
}

public final class FetchValueVar : Value, IRenderable, Targetable
{
    /* Name of variable to fetch from */
    private string varName;

    this(string varName)
    {
        this.varName = varName;
        
        addInfo = "fetchVarValName: "~varName;
    }

    public string getTarget()
    {
        return this.varName;
    }

    public void setTarget(string target)
    {
        this.varName = target;
    }
    
    public string render()
    {
        return varName;
    }
}

/** 
 * A reference to a data value
 * of which is a non-scalar type
 * but also not an array.
 */
public abstract class CompositeDataRef : Value, IRenderable
{
    private Value via;

    this(Value target)
    {
        this.via = target;
    }

    public final Value getVia()
    {
        return this.via;
    }

    public string render()
    {
        import std.stdio;
        writeln("dd: ", this.via);
        return tryRender(this.via);
    }
}

/** 
 * This instruction is generated
 * when a struct instance itself
 * is referred to
 */
public final class StructDataRef : CompositeDataRef
{
    this(Value via)
    {
        super(via);
    }
}

/** 
 * This instruction is generated
 * when a class itself is referred
 * to
 */
public final class ClassDataRef : CompositeDataRef
{
    this(Value via)
    {
        super(via);
    }
}

/** 
 * Any sort of reference to a member
 * inside of a composite data structure
 */
public abstract class MemberRefInstr : Value
{

}

/** 
 * A reference to a member of a given
 * struct. The struct is derived from
 * a `Value`-based instruction that
 * would derive it and then the member
 * likewise is also a `Value`-based
 * instruction
 */
public final class StructMemberRefInstr : MemberRefInstr, IRenderable
{
    private Value structInstance;
    private Value memberTarget;

    this
    (
        Value structInstance,
        Value memberTarget
    )
    {
        this.structInstance = structInstance;
        this.memberTarget = memberTarget;
    }

    public Value getStructInstance()
    {
        return this.structInstance;
    }

    public Value getMemberTarget()
    {
        return this.memberTarget;
    }

    public string render()
    {
        return format
        (
            "(structInstance: %s, member: %s)",
            tryRender(structInstance),
            tryRender(memberTarget)
        );
    }
}

/* Used for integers */
public final class LiteralValue : Value, IRenderable
{
    /* Data */
    private string data;

    this(string data, Type type)
    {
        this.data = data;
        this.type = type;

        addInfo = "Data: "~to!(string)(data)~", Type: "~to!(string)(type);
    }

    public string getLiteralValue()
    {
        return data;
    }

    public override string toString()
    {
        return produceToStrEnclose("Data: "~to!(string)(data)~", Type: "~to!(string)(type));
    }

    public string render()
    {
        return data;
    }
}

public final class LiteralValueFloat : Value, IRenderable
{
    /* Data */
    private string data;

    this(string data, Type type)
    {
        this.data = data;
        this.type = type;

        addInfo = "Data: "~to!(string)(data)~", Type: "~to!(string)(type);
    }

    public string getLiteralValue()
    {
        return data;
    }

    public override string toString()
    {
        return produceToStrEnclose("Data: "~to!(string)(data)~", Type: "~to!(string)(type));
    }

    public string render()
    {
        return data;
    }
}

/* FIXME: Implement this */
/**
* TODO: This should take in:
*
* 1. The string literal
* 2. It should assign it to an interning pool and get the ID (associate one with the string literal if equal/in-the-pool)
*/
public final class StringLiteral : Value, IRenderable
{
    /* String interning pool */
    private static int[string] internmentCamp;
    private static int rollCount = 0;
    private string stringLiteral;

    
    this(string stringLiteral)
    {
        this.stringLiteral = stringLiteral;

        /* Intern the string */
        intern(stringLiteral);

        addInfo = "StrLit: `"~stringLiteral~"`, InternID: "~to!(string)(intern(stringLiteral));
    }

    public static int intern(string strLit)
    {
        /* Search for the string (if it exists return it's pool ID) */
        foreach(string curStrLit; internmentCamp.keys())
        {
            if(cmp(strLit, curStrLit) == 0)
            {
                return internmentCamp[strLit];
            }
        }

        /* If not, create a new entry (pool it) and return */
        internmentCamp[strLit] = rollCount;
        rollCount++; /* TODO: Overflow check */

        return rollCount-1;
    }

    public string getStringLiteral()
    {
        return stringLiteral;
    }

    public string render()
    {
        return format("\"%s\"", stringLiteral);
    }
}

/**
* BinOpInstr instruction
*
* Any sort of Binary Operator
*/
public class BinOpInstr : Value, IRenderable
{
    public const Value lhs;
    public const Value rhs;
    public const SymbolType operator;

    this(Value lhs, Value rhs, SymbolType operator)
    {
        this.lhs = lhs;
        this.rhs = rhs;
        this.operator = operator;

        addInfo = "BinOpType: "~to!(string)(operator)~", LhsValInstr: "~lhs.toString()~", RhsValInstr: "~rhs.toString();
    }

    public string render()
    {
        // TODO: Remove casts from const
        return format
        (
            "%s %s %s",
            tryRender(cast(Instruction)this.lhs),
            getCharacter(this.operator),
            tryRender(cast(Instruction)this.rhs)
        );
    }
}

/**
* UnaryOpInstr instruction
*
* Any sort of Unary Operator
*/
public class UnaryOpInstr : Value, IRenderable
{
    private Value exp;
    private SymbolType operator;

    this(Value exp, SymbolType operator)
    {
        this.exp = exp;
        this.operator = operator;

        addInfo = "UnaryOpType: "~to!(string)(operator)~", Instr: "~exp.toString();
    }

    public SymbolType getOperator()
    {
        return operator;
    }

    public Value getOperand()
    {
        return exp;
    }

    public string render()
    {
        return format("%s%s", getCharacter(operator), tryRender(exp));
    }
}

/**
* 2022 New things
*
*/

//public class CallInstr : Instruction
public class CallInstr : Value
{

}

public class FuncCallInstr : CallInstr, IRenderable, Targetable
{
    /** 
     * This is described in the corresponding AST node
     * `FunctionCall`. See that. For short, function calls
     * from within expressions and those as appearing as statements
     * require a tiny different code gen but for Instructions
     * their emit also needs a tiny difference
     */
    private bool statementLevel = false;

    /* Per-argument instrructions */
    private Value[] evaluationInstructions;

    private string functionName;

    this(string functionName, ulong argEvalInstrsSize)
    {
        this.functionName = functionName;
        evaluationInstructions.length = argEvalInstrsSize;

        updateAddInfo();
    }

    /**
    * FuncCallInstr is built-bit-by-bit so toString information will change
    */
    private void updateAddInfo()
    {
        addInfo = "FunctionName: "~functionName ~" EvalInstrs: "~ to!(string)(getEvaluationInstructions());
    }

    public void setEvalInstr(ulong argPos, Value instr)
    {
        evaluationInstructions[argPos] = instr;
        updateAddInfo();
    }

    public Value[] getEvaluationInstructions()
    {
        return evaluationInstructions;
    }

    public size_t getArgCount()
    {
        return evaluationInstructions.length;
    }

    /** 
     * Determines whether this function call instruction
     * is within an expression or a statement itself
     *
     * Returns: true if statement-level, false otherwise
     */
    public bool isStatementLevel()
    {
        return statementLevel;
    }

    /** 
     * Marks this function call instruction as statement
     * level
     */
    public void markStatementLevel()
    {
        statementLevel = true;
    }

    public string getTarget()
    {
        return this.functionName;
    }

    public void setTarget(string targetName)
    {
        this.functionName = targetName;
    }
    
    public string render()
    {
        string arg_s;
        foreach(Value arg; evaluationInstructions)
        {
            arg_s ~= format("%s, ", tryRender(arg));
        }
        import std.string : strip;
        arg_s = strip(arg_s, ", ");

        return format("%s(%s)", functionName, arg_s);
    }
}

/** 
 * An instruction of whom's job
 * is to execute an arbitrary
 * `Value`-based instruction
 */
public final class ExpressionStatementInstruction : Instruction
{
    private Value exprInstr;

    this(Value expressionInstruction)
    {
        this.exprInstr = expressionInstruction;
    }

    public Value getExprInstruction()
    {
        return this.exprInstr;
    }
}

public final class ReturnInstruction : Instruction, IRenderable
{
    private Value returnExprInstr;

    this(Value returnExprInstr)
    {
        this.returnExprInstr = returnExprInstr;
    }

    this()
    {

    }

    public Value getReturnExpInstr()
    {
        return returnExprInstr;
    }

    public bool hasReturnExpInstr()
    {
        return returnExprInstr !is null;
    }

    public string render()
    {
        return format("return %s", tryRender(returnExprInstr));
    }
}

public final class IfStatementInstruction : Instruction, IRenderable
{
    private BranchInstruction[] branchInstructions;

    this(BranchInstruction[] branchInstructions)
    {
        this.branchInstructions = branchInstructions;

        addInfo = "Branches: "~to!(string)(branchInstructions);
    }

    public BranchInstruction[] getBranchInstructions()
    {
        return branchInstructions;
    }

    public string render()
    {
        bool fst = true;
        string s;
        foreach(BranchInstruction b; branchInstructions)
        {
            if(b.hasConditionInstr()) // `if` or `else if`
            {
                if(fst) // `if`
                {
                    s ~= format("if(%s) {}\n", tryRender(b.getConditionInstr()));
                    fst = false;
                }
                else // `else if`
                {
                    s ~= format("else if(%s) {}\n", tryRender(b.getConditionInstr()));
                }
            }
            else // `else`
            {
                s ~= "else {}";
            }
        }

        return s;
    }
}

public final class WhileLoopInstruction : Instruction, IRenderable
{
    private BranchInstruction branchInstruction;

    this(BranchInstruction branchInstruction)
    {
        this.branchInstruction = branchInstruction;

        addInfo = "Branch: "~to!(string)(branchInstruction);
    }

    public BranchInstruction getBranchInstruction()
    {
        return branchInstruction;
    }

    public string render()
    {
        return format("while(%s) {}", tryRender(branchInstruction.getConditionInstr()));
    }
}

public final class ForLoopInstruction : Instruction, IRenderable
{
    private Instruction preRunInstruction;
    private BranchInstruction branchInstruction;
    private bool hasPostIterate;

    this(BranchInstruction branchInstruction, Instruction preRunInstruction = null, bool hasPostIterate = false)
    {
        this.branchInstruction = branchInstruction;
        this.preRunInstruction = preRunInstruction;

        addInfo = (hasPreRunInstruction() ? "PreRun: "~to!(string)(preRunInstruction)~", " : "")~"Branch: "~to!(string)(branchInstruction);

        this.hasPostIterate = hasPostIterate;
    }

    public bool hasPostIterationInstruction()
    {
        return hasPostIterate;
    }

    public Instruction getPreRunInstruction()
    {
        return preRunInstruction;
    }

    public bool hasPreRunInstruction()
    {
        return !(preRunInstruction is null);
    }

    public BranchInstruction getBranchInstruction()
    {
        return branchInstruction;
    }

    public string render()
    {
        string postIterate_s = hasPostIterationInstruction() ? tryRender(branchInstruction.getBodyInstructions()[$-1]) : "";
        string preRun_s = hasPreRunInstruction() ? tryRender(getPreRunInstruction()) : "";
        string iterInstr_s = tryRender(getBranchInstruction().getConditionInstr());
        return format("for(%s; %s; %s) {}", preRun_s, iterInstr_s, postIterate_s);
    }
}

public final class BranchInstruction : Instruction
{
    private Value branchConditionInstr;
    private Instruction[] bodyInstructions;

    this(Value conditionInstr, Instruction[] bodyInstructions)
    {
        this.branchConditionInstr = conditionInstr;
        this.bodyInstructions = bodyInstructions;

        addInfo = "CondInstr: "~to!(string)(branchConditionInstr)~", BBodyInstrs: "~to!(string)(bodyInstructions);
    }

    public bool hasConditionInstr()
    {
        return !(branchConditionInstr is null);
    }

    public Value getConditionInstr()
    {
        return branchConditionInstr;
    }

    public Instruction[] getBodyInstructions()
    {
        return bodyInstructions;
    }
}

public final class PointerDereferenceAssignmentInstruction : Instruction, IRenderable
{
    private Value pointerEvalInstr;
    private Value assigmnetExprInstr;
    private ulong derefCount;

    this(Value pointerEvalInstr, Value assigmnetExprInstr, ulong derefCount)
    {
        this.pointerEvalInstr = pointerEvalInstr;
        this.assigmnetExprInstr = assigmnetExprInstr;
        this.derefCount = derefCount;
    }

    public Value getPointerEvalInstr()
    {
        return pointerEvalInstr;
    }

    public Value getAssExprInstr()
    {
        return assigmnetExprInstr;
    }

    public ulong getDerefCount()
    {
        return derefCount;
    }

    public string render()
    {
        import niknaks.text : genX;

        return format
        (
            "%s%s = %s",
            genX(getDerefCount(), "*"),
            tryRender(getPointerEvalInstr()),
            tryRender(getAssExprInstr())
        );
    }
}

public final class DiscardInstruction : Instruction, IRenderable
{
    private Value exprInstr;

    this(Value exprInstr)
    {
        this.exprInstr = exprInstr;
    }

    public Value getExpressionInstruction()
    {
        return exprInstr;
    }

    public string render()
    {
        return format("discard %s", tryRender(exprInstr));
    }
}

public final class CastedValueInstruction : Value, IRenderable
{
    /* The uncasted original instruction that must be executed-then-trimmed (casted) */
    private Value uncastedValue;

    /** 
     * Used in code emitting, this is related to
     * #140. Really just a C+DGen thing.
     *
     * Signals that we shouldn't emit any special
     * casting syntax in the underlying emitter.
     */
    private bool relax;

    this(Value uncastedValue, Type castToType)
    {
        this.uncastedValue = uncastedValue;
        this.type = castToType;

        // Relaxing is disabled by default
        this.relax = false;
    }

    public Value getEmbeddedInstruction()
    {
        return uncastedValue;
    }

    public Type getCastToType()
    {
        return type;
    }

    public bool isRelaxed()
    {
        return relax;
    }

    public void setRelax(bool relax)
    {
        this.relax = relax;
    }

    public string render()
    {
        return format("cast(%s)%s", getCastToType(), tryRender(getEmbeddedInstruction()));
    }
}

public final class ArrayIndexInstruction : Value, IRenderable
{
    /* Index-to instruction */
    private Value indexTo;

    /* The index */
    private Value index;

    this(Value indexTo, Value index)
    {
        this.indexTo = indexTo;
        this.index = index;
    }

    public Value getIndexInstr()
    {
        return index;
    }

    public Value getIndexedToInstr()
    {
        return indexTo;
    }

    public override string toString()
    {
        return "ArrayIndexInstr [IndexTo: "~indexTo.toString()~", Index: "~index.toString()~"]";
    }

    public string render()
    {
        return format("%s[%s]", tryRender(getIndexedToInstr()), tryRender(getIndexInstr()));
    }
}

//TODO: ArrayIndexAssignmentInstruction
public final class ArrayIndexAssignmentInstruction : Instruction, IRenderable
{
    // TODO: We then need the left hand side array evaluation instruction (a pointer value basically)
    // private Value arrayPtrEval;

    // TODO: We then also need a `Value` field for the index expression instruction
    // private Value index;

    // NOTE: We now to the above to using an ArrayIndexInstruction
    private ArrayIndexInstruction arrayPtrEval;

    // TODO: We then also need another `Value` field for the expression instruction
    // ... being assigned into the pointer-array
    private Value assignment;

    this(ArrayIndexInstruction arrayPtrEval, Value assignment)
    {
        this.arrayPtrEval = arrayPtrEval;
        // this.index = index;
        this.assignment = assignment;
    }

    public ArrayIndexInstruction getArrayPtrEval()
    {
        return arrayPtrEval;
    }

    public Value getAssignmentInstr()
    {
        return assignment;
    }

    public string render()
    {
        return format("%s = %s", tryRender(getArrayPtrEval()), tryRender(getAssignmentInstr()));
    }
}

// TODO: StackArrayIndexInstruction
public final class StackArrayIndexInstruction : Value, IRenderable
{
    /* Index-to instruction */
    private Value indexTo;

    /* The index */
    private Value index;

    this(Value indexTo, Value index)
    {
        this.indexTo = indexTo;
        this.index = index;
    }

    public Value getIndexInstr()
    {
        return index;
    }

    public Value getIndexedToInstr()
    {
        return indexTo;
    }

    public override string toString()
    {
        return "StackArrayIndexInstr [IndexTo: "~indexTo.toString()~", Index: "~index.toString()~"]";
    }

    public string render()
    {
        return format("%s[%s]", tryRender(getIndexedToInstr()), tryRender(getIndexInstr()));
    }
}

public final class StackArrayIndexAssignmentInstruction : Instruction, IRenderable
{
    // Who is being indexed on and the index itself
    private ArrayIndexInstruction arrAndIndex;

    // We then also need another `Value` field for the expression instruction
    // ... being assigned into the stack-array at said index
    private Value assignment;

    this(ArrayIndexInstruction arrAndIndex, Value assignment)
    {
        this.arrAndIndex = arrAndIndex;
        this.assignment = assignment;
    }

    public Value getArrayInstr()
    {
        return arrAndIndex.getIndexedToInstr();
    }

    public Value getArrayIndexInstruction()
    {
        return arrAndIndex.getIndexInstr();
    }

    public Value getAssignedValue()
    {
        return assignment;
    }

    public override string toString()
    {
        import std.string : format;
        return format
        (
            "StackArrayASSIGN [to: %s, index: %s, assignment: %s]",
            getArrayInstr(),
            getArrayIndexInstruction(),
            assignment
        );
    }

    public string render()
    {
        return format("%s = %s", tryRender(arrAndIndex), tryRender(getAssignedValue()));
    }
}

/** 
 * This represents the assignment of
 * some `Value`-based value to a 
 * member of a struct. The latter
 * is represented by a `StructMemberRefInstr`
 */
public final class StructMemberAssignmentInstr : Instruction
{
    private StructMemberRefInstr m_ref;
    private Value assVal;

    this
    (
        StructMemberRefInstr structMemberRef,
        Value assignmentValue
    )
    {
        this.m_ref = structMemberRef;
        this.assVal = assignmentValue;
    }

    public StructMemberRefInstr getStructMemberRef()
    {
        return this.m_ref;
    }

    public Value getAssignmentInstr()
    {
        return this.assVal;
    }
}