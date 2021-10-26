module compiler.codegen.instruction;

import std.conv : to;

public class Instruction
{
    protected string addInfo;

    this()
    {
        // this.instructionName = instructionName;
    }

    public final override string toString()
    {
        return "[Instruction: "~this.classinfo.name~":"~addInfo~"]";
    }
}

public class FetchInst :  Instruction
{

}

public class Value : Instruction
{

}

public class StorageDeclaratio : Instruction
{

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
}

public final class VariableDeclaration : StorageDeclaratio
{
    /* Name of variable being declared */
    public string varName;

    /* Length */
    public byte length;

    this(string varName, byte len)
    {
        this.varName = varName;
        this.length = len;

        addInfo = "varName: "~varName;
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
}

/**
* Addition instruction
*
* Type: integers
* Signedness: unsigned/signed (two's complement)
*/
public class AddInstr : Instruction
{
    private Instruction lhs;
    private Instruction rhs;

    this(Instruction lhs, Instruction rhs)
    {
        this.lhs = lhs;
        this.rhs = rhs;
    }
}