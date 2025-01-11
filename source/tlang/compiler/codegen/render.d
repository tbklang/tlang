/** 
 * Instruction rendering
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.render;
import tlang.compiler.codegen.instruction : Instruction;

/** 
 * Any instruction which implements
 * this method can have a string
 * representation of itself generated
 * in such a manner as to visually
 * represent the structure of the
 * instruction itself
 *
 * Authors: Tristan Brice Velloza Kildaire
 */
public interface IRenderable
{
    /** 
     * Renders the instruction
     *
     * Returns: the string
     * representation
     */
    public string render();
}

/** 
 * Attempts to render the given
 * instruction. If the instruction
 * supports the `IRenderable`
 * interface then that will be
 * used, otherwise the name of
 * the instruction will be the
 * fallback
 *
 * Params:
 *   instr = the instruction
 * Returns: the representation
 */
public string tryRender(Instruction instr)
{
    IRenderable r_i = cast(IRenderable)instr;

    if(r_i is null)
    {
        return instr.classinfo.name;
    }
    else
    {
        return r_i.render();    
    }
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : LiteralValue;
    import tlang.compiler.codegen.instruction : BinOpInstr;
    import tlang.compiler.symbols.typing.core : Type;
    import tlang.compiler.symbols.check : SymbolType;

    import tlang.misc.logging;
}

unittest
{
    LiteralValue lhs = new LiteralValue("1", new Type("int"));
    LiteralValue rhs = new LiteralValue("2", new Type("int"));
    Instruction binOp = new BinOpInstr(lhs, rhs, SymbolType.ADD);

    string s_out = tryRender(binOp);
    DEBUG("s_out: ", s_out);
    assert(s_out == "1 + 2");
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : Value;
    import tlang.compiler.codegen.instruction : BranchInstruction;
    import tlang.compiler.codegen.instruction : IfStatementInstruction;
}

unittest
{
    LiteralValue lhs_1 = new LiteralValue("1", new Type("int"));
    LiteralValue rhs_1 = new LiteralValue("2", new Type("int"));
    Value cond_1 = new BinOpInstr(lhs_1, rhs_1, SymbolType.EQUALS);

    BranchInstruction b_1 = new BranchInstruction(cond_1, []);

    LiteralValue lhs_2 = new LiteralValue("2", new Type("int"));
    LiteralValue rhs_2 = new LiteralValue("2", new Type("int"));
    Value cond_2 = new BinOpInstr(lhs_2, rhs_2, SymbolType.EQUALS);

    BranchInstruction b_2 = new BranchInstruction(cond_2, []);

    BranchInstruction b_3 = new BranchInstruction(null, []);

    IfStatementInstruction if_1 = new IfStatementInstruction([b_1, b_2, b_3]);

    string s_out = tryRender(if_1);
    DEBUG("s_out: ", s_out);
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : PointerDereferenceAssignmentInstruction;
    import tlang.compiler.codegen.instruction : FuncCallInstr;
    import tlang.compiler.codegen.instruction : ArrayIndexInstruction;
    import tlang.compiler.codegen.instruction : FetchValueVar;
}

unittest
{
    Type intType = new Type("int");
    FuncCallInstr fcall = new FuncCallInstr("getPtrDouble", 2);
    fcall.setEvalInstr(0, new LiteralValue("65", intType));
    fcall.setEvalInstr(1, new ArrayIndexInstruction(new FetchValueVar("arr"), new LiteralValue("66", intType)));
    PointerDereferenceAssignmentInstruction ptrDeref = new PointerDereferenceAssignmentInstruction
    (
        fcall,
        new LiteralValue("1", intType),
        2
    );

    string s_out = tryRender(ptrDeref);
    DEBUG("s_out: ", s_out);
    assert(s_out == "**getPtrDouble(65, arr[66]) = 1");
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : WhileLoopInstruction;
}

unittest
{
    LiteralValue lhs_1 = new LiteralValue("1", new Type("int"));
    LiteralValue rhs_1 = new LiteralValue("2", new Type("int"));
    Value cond_1 = new BinOpInstr(lhs_1, rhs_1, SymbolType.EQUALS);

    BranchInstruction b_1 = new BranchInstruction(cond_1, []);
    WhileLoopInstruction wl = new WhileLoopInstruction(b_1);

    string s_out = tryRender(wl);
    DEBUG("s_out: ", s_out);
    assert(s_out == "while(1 == 2) {}");
}

version(unittest)
{
    import tlang.compiler.codegen.instruction : ForLoopInstruction;
    import tlang.compiler.codegen.instruction : VariableDeclaration, VariableAssignmentInstr;
}

unittest
{
    LiteralValue lhs_1 = new LiteralValue("1", new Type("int"));
    LiteralValue rhs_1 = new LiteralValue("2", new Type("int"));
    Value cond_1 = new BinOpInstr(lhs_1, rhs_1, SymbolType.EQUALS);

    Instruction pre = new VariableDeclaration("i", 1, new Type("ubyte"), null);
    Instruction post = new VariableAssignmentInstr("i", new LiteralValue("60", new Type("ubyte")));

    BranchInstruction b_1 = new BranchInstruction(cond_1, [post]);
    ForLoopInstruction wl = new ForLoopInstruction(b_1, pre, true);

    string s_out = tryRender(wl);
    DEBUG("s_out: ", s_out);
    assert(s_out == "for(ubyte i; 1 == 2; i = 60) {}");
}