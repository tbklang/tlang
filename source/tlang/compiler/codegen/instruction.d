module compiler.codegen.instruction;

import std.conv : to;
import compiler.typecheck.dependency.core : Context;
import std.string : cmp;
import misc.utils : symbolRename;
import compiler.symbols.data : SymbolType;
import compiler.symbols.check : getCharacter;
import gogga;

/** 
 * TODO: We should actually remove the emits from here probably and rather do those in DGen
 * as they are C specific
 */

public class Instruction
{
    /* Context for the Instruction (used in emitter for name resolution) */
    public Context context;

    protected string addInfo;

    this()
    {
        // this.instructionName = instructionName;
    }

    public final override string toString()
    {
        return "[Instruction: "~this.classinfo.name~":"~addInfo~"]";
    }

    public string emit()
    {
        return "TODO: This instruction has not provided an emit text yet! (This is an error!)";
    }

    public final Context getContext()
    {
        return context;
    }
}

public class FetchInst :  Instruction
{

}

public class Value : Instruction
{

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

    public Instruction data;

    this(string varName, Instruction data)
    {
        this.varName = varName;
        this.data = data;

        addInfo = "assignTo: "~varName~", valInstr: "~data.toString();
    }

    public override string emit()
    {
        gprintln("Is ContextNull?: "~to!(string)(context is null));
        auto typedEntityVariable = context.tc.getResolver().resolveBest(context.getContainer(), varName); //TODO: Remove `auto`
        string typedEntityVariableName = context.tc.getResolver().generateName(context.getContainer(), typedEntityVariable);


        import compiler.codegen.mapper : SymbolMapper;
        string renamedSymbol = SymbolMapper.symbolLookup(context.getContainer(), typedEntityVariableName);


        return renamedSymbol~" = "~data.emit()~";";
        // return "<TODO: VarAssAssignment ("~data.emit()~")";
    }
}

public final class VariableDeclaration : StorageDeclaration
{
    /* Name of variable being declared */
    public const string varName;

    /* Length */
    public const byte length;

    /* Type of the variable being declared */
    public const string varType;

    //TODO: This must take in type information
    this(string varName, byte len, string varType)
    {
        this.varName = varName;
        this.length = len;
        this.varType = varType;

        addInfo = "varName: "~varName;
    }

    /** 
     * Emits a string of the form: 
     *
     *      <varType> <varName>;
     *
     * Returns: The emitted code
     */
    public override string emit()
    {
        auto typedEntityVariable = context.tc.getResolver().resolveBest(context.getContainer(), varName); //TODO: Remove `auto`
        string typedEntityVariableName = context.tc.getResolver().generateName(context.getContainer(), typedEntityVariable);

        //NOTE: We should remove all dots from generated symbol names as it won't be valid C (I don't want to say C because
        // a custom CodeEmitter should be allowed, so let's call it a general rule)
        //
        //simple_variables.x -> simple_variables_x
        //NOTE: We may need to create a symbol table actually and add to that and use that as these names
        //could get out of hand (too long)
        // NOTE: Best would be identity-mapping Entity's to a name
        string renamedSymbol = symbolRename(typedEntityVariableName);

        import compiler.codegen.mapper : SymbolMapper;
        renamedSymbol = SymbolMapper.symbolLookup(context.getContainer(), varName);

        return varType~" "~renamedSymbol~";";
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
    public ulong data;
    public byte len;

    this(ulong data, byte len)
    {
        this.data = data;
        this.len = len;

        addInfo = "Data: "~to!(string)(data)~", Length: "~to!(string)(len);
    }

    public override string emit()
    {
        return to!(string)(data);
    }
}

public final class LiteralValueFloat : Value
{
    /* Data */
    public double data; /* TODO: Is this best way to store? Consirring floats/doubles */
    public byte len;

    this(double data, byte len)
    {
        this.data = data;
        this.len = len;

        addInfo = "Data: "~to!(string)(data)~", Length: "~to!(string)(len);
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
    private Instruction lhs;
    private Instruction rhs;
    private SymbolType operator;

    this(Instruction lhs, Instruction rhs, SymbolType operator)
    {
        this.lhs = lhs;
        this.rhs = rhs;
        this.operator = operator;

        addInfo = "BinOpType: "~to!(string)(operator)~", LhsValInstr: "~lhs.toString()~", RhsValInstr: "~rhs.toString();
    }

    public override string emit()
    {
        return lhs.emit()~to!(string)(getCharacter(operator))~rhs.emit();
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
}