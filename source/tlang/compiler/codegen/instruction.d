module compiler.codegen.instruction;

import std.conv : to;
import compiler.typecheck.dependency.core : Context;
import std.string : cmp;
import compiler.symbols.data : SymbolType;
import compiler.symbols.check : getCharacter;
import gogga;
import compiler.symbols.typing.core : Type;

public class Instruction
{
    /* Context for the Instruction (used in emitter for name resolution) */
    public Context context; //TODO: Make this private and add a setCOntext

    protected string addInfo;

    this()
    {
        // this.instructionName = instructionName;
    }

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

public class FetchInst :  Instruction
{

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

public class VariableAssignmentInstr : Instruction
{
    /* Name of variable being declared */
    public string varName; /*TODO: Might not be needed */

    public Value data;

    this(string varName, Value data)
    {
        this.varName = varName;
        this.data = data;

        addInfo = "assignTo: "~varName~", valInstr: "~data.toString();
    }
}

public final class VariableDeclaration : StorageDeclaration
{
    /* Name of variable being declared */
    public const string varName;

    /* Length */
    public const byte length;

    /* Type of the variable being declared */
    public const Type varType;

    /* VariableAssignmentInstr-instruction to be assigned */
    private VariableAssignmentInstr varAssInstr;

    //TODO: This must take in type information
    this(string varName, byte len, Type varType, VariableAssignmentInstr varAssInstr)
    {
        this.varName = varName;
        this.length = len;
        this.varType = varType;

        this.varAssInstr = varAssInstr;

        addInfo = "varName: "~varName;
    }

    public VariableAssignmentInstr getAssignmentInstr()
    {
        return varAssInstr;
    }

}

public final class FetchValueVar : Value
{
    /* Name of variable to fetch from */
    public string varName;

    /* Length */
    public byte length;

    this(string varName, byte len)
    {
        this.varName = varName;
        this.length = len;

        addInfo = "fetchVarValName: "~varName~", VarLen: "~to!(string)(length);
    }
}

/* Used for integers */
public final class LiteralValue : Value
{
    /* Data */
    public string data;

    this(string data, Type type)
    {
        this.data = data;
        this.type = type;

        addInfo = "Data: "~to!(string)(data)~", Type: "~to!(string)(type);
    }

    public override string toString()
    {
        return produceToStrEnclose("Data: "~to!(string)(data)~", Type: "~to!(string)(type));
    }
}

public final class LiteralValueFloat : Value
{
    /* Data */
    public string data; /* TODO: Is this best way to store? Consirring floats/doubles */

    this(string data, Type type)
    {
        this.data = data;
        this.type = type;

        addInfo = "Data: "~to!(string)(data)~", Type: "~to!(string)(type);
    }

    public override string toString()
    {
        return produceToStrEnclose("Data: "~to!(string)(data)~", Type: "~to!(string)(type));
    }
}

/* FIXME: Implement this */
/**
* TODO: This should take in:
*
* 1. The string literal
* 2. It should assign it to an interning pool and get the ID (associate one with the string literal if equal/in-the-pool)
*/
public final class StringLiteral : Value
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
}

/**
* BinOpInstr instruction
*
* Any sort of Binary Operator
*/
public class BinOpInstr : Value
{
    public const Instruction lhs;
    public const Instruction rhs;
    public const SymbolType operator;

    this(Instruction lhs, Instruction rhs, SymbolType operator)
    {
        this.lhs = lhs;
        this.rhs = rhs;
        this.operator = operator;

        addInfo = "BinOpType: "~to!(string)(operator)~", LhsValInstr: "~lhs.toString()~", RhsValInstr: "~rhs.toString();
    }
}

/**
* UnaryOpInstr instruction
*
* Any sort of Unary Operator
*/
public class UnaryOpInstr : Value
{
    private Instruction exp;
    private SymbolType operator;

    this(Instruction exp, SymbolType operator)
    {
        this.exp = exp;
        this.operator = operator;

        addInfo = "UnaryOpType: "~to!(string)(operator)~", Instr: "~exp.toString();
    }

    public SymbolType getOperator()
    {
        return operator;
    }

    public Instruction getOperand()
    {
        return exp;
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

public class FuncCallInstr : CallInstr
{
    /* Per-argument instrructions */
    private Value[] evaluationInstructions;

    public const string functionName;

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
}


public final class ReturnInstruction : Instruction
{
    private Value returnExprInstr;

    this(Value returnExprInstr)
    {
        this.returnExprInstr = returnExprInstr;
    }

    public Value getReturnExpInstr()
    {
        return returnExprInstr;
    }
}

public final class IfStatementInstruction : Instruction
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
}

public final class WhileLoopInstruction : Instruction
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
}

public final class ForLoopInstruction : Instruction
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


public final class PointerDereferenceAssignmentInstruction : Instruction
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
}

public final class DiscardInstruction : Instruction
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
}

public final class CastedValueInstruction : Value
{
    /* The uncasted original instruction that must be executed-then-trimmed (casted) */
    private Value uncastedValue;

    private Type castToType;

    this(Value uncastedValue, Type castToType)
    {
        this.uncastedValue = uncastedValue;
        this.castToType = castToType;
    }

    public Value getEmbeddedInstruction()
    {
        return uncastedValue;
    }

    public Type getCastToType()
    {
        return castToType;
    }
}