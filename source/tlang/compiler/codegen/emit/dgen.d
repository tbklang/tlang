module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;
import compiler.codegen.emit.dgenregs;
import gogga;

public final class DCodeEmitter : CodeEmitter
{

    /**
    * TODO:
    *
    * 1. We need to keep track of pushes
    * 2. WHen entering a new function we save old, use a queue
    * 3. So we need to do something like that to be able to restore
    */


    this(TypeChecker typeChecker, File file)
    {
        super(typeChecker, file);

        /* Initialize the register file */
        initRegisterFile();
    }

    /**
    * TODO: We will need state as to where we are etc.
    */

    private ulong pushCount;

    /**
    * RSP value before we started (needed for proper D exit/restore/main()-unwind)
    *
    * R15 (Richard 15) <- never use this register besides here and `restoreDInfo()`
    */
    private void saveDInfo()
    {
        file.writeln(`
        asm
        {
            mov R15, RSP;
        }
        `);
    }
    private void restoreDInfo()
    {
        file.writeln(`
        asm
        {
            mov RSP, R15;
        }
        `);
    }

    
    private SList!(Register) registers;


    private void initRegisterFile()
    {
        /* R's registers */
        for(ulong i = 0; i <= 6; i++)
        {
            /* Generate number prefix */
            string prefix = to!(string)(i+8);
            RichardRegister register = new RichardRegister(prefix);


            registers.insert(register);
        }
        
        /* TODO: Add othe registers (and in dgenregs.d) */
        
    }

    private Register getRegister(ubyte size)
    {
        
        
        foreach(Register register; registers)
        {
            if(!register.isInUse())
            {
                foreach(ubyte sizeC; register.getSupportedSizes())
                {
                    if(sizeC == size)
                    {
                        register.allocate(size);

                        return register;
                    }
                }
            }
        }

        throw new Exception("Ran out of registers to allocate, this is a compiler bug!");

        // return null;
    }

    /**
    * RegisterSet HelperMethod
    */
    private string setRegisterValue(Register register, ulong value)
    {
        string settingASM = `
        asm
        {
            mov `~register.getUsableName()~", "~to!(string)(value)~";"~`
        }
        `;

        return settingASM;
    }

    public Register emitAndProcessExpression(Instruction instr)
    {
        Register registerToCheck;

        /**
        * Literal case
        */
        if(cast(LiteralValue)instr)
        {
            LiteralValue litValInstr = cast(LiteralValue)instr;

            Register valReg = getRegister(litValInstr.len);

            /* Emit setting code */
            file.writeln(setRegisterValue(valReg, litValInstr.data));


            /* Set as return */
            registerToCheck = valReg;

        }
        /**
        * FIXME: Remove this as it is just to stop segfaulkts for 
        * yet-to-be-suppirted recursive descent emitting
        */
        else
        {
            Register valReg = getRegister(1);

            /* Emit setting code */
            file.writeln(setRegisterValue(valReg, 65));

            /* Set as return */
            registerToCheck = valReg;
        }


        


        return registerToCheck;
    }

    /**
    * Represents a function's code
    *
    * Includes: Name, address, the assembly
    * for it (for all entities within)
    */
    private struct FunctionCode
    {
        public string functionName;
        public ulong entryAddress;

        /**
        * Block-by-block asm-D emitted
        * blocks
        */
        public string[] asmLines;

        /* TODO: Return register name (Actually use standard rax, eax for compat) */
    }


    // private string[] emitFunctionEnter()

    /**
    * Current stackpointer along with the offsets
    * from it to variables (a varName -> offset map)
    *
    * The stack pointer is only used in a magnitude
    * sense as in reality x86 grows downwards when we
    * push variables
    */
    private ulong stackPointer;
    private ulong[string] variableOffsets;

    private void pushVariable(string name, ubyte size)
    {
        stackPointer+=size;

        variableOffsets[name] = size;
    }

    private ulong getVariableOffset(string name)
    {

        foreach(string variables; variableOffsets.keys())
        {
            if(cmp(name, variables) == 0)
            {
                return variableOffsets[name];
            }
        }
        
        throw new Exception("Could not find variable offset for variable '"~name~"'");
    }

    public override void emit()
    {
        /* Emit initial struccture */
        emitIninitailModule();

        /* Save D info */
        saveDInfo();

        /* TODO: Implement me */
        foreach(Instruction instruction; instructions)
        {
            /**
            * compiler.codegen.instruction.VariableDeclaration
            */
            if(cast(VariableDeclaration)instruction)
            {
                VariableDeclaration varDecInstr = cast(compiler.codegen.instruction.VariableDeclaration)instruction;

                /**
                * Byte-sized variable
                */
                if(varDecInstr.length == 1)
                {
                    file.writeln(`asm
                    {
                        sub RSP, 1;
                    }
                    `);
                }
                /**
                * Short-sized variable
                */
                else if(varDecInstr.length == 2)
                {
                    file.writeln(`asm
                    {
                        sub RSP, 2;
                    }
                    `);
                }
                /**
                * Long-sized variable
                */
                else if(varDecInstr.length == 4)
                {
                    file.writeln(`asm
                    {
                        sub RSP, 4;
                    }
                    `);
                }
                /**
                * Quad-sized variable
                */
                else if(varDecInstr.length == 8)
                {
                    file.writeln(`asm
                    {
                        sub RSP, 8;
                    }
                    `);
                }
                
                
                /* TODO: We need to build map of stakc positions, maybe not */


                /**
                * FIXME: We must grab the Context object here to get the Container
                * to be able to resolve the absolute path of this variable using
                * the grand resolver (solved, as of 9th November we have context)
                *
                * FIXME: NOT ALL HAVE CONTEXT YET!!!
                */
                gprintln(varDecInstr.context);
                pushVariable(varDecInstr.varName, varDecInstr.length);
            }
            /**
            * compiler.codegen.instruction.VariableAssignmentInstr
            */
            else if(cast(VariableAssignmentInstr)instruction)
            {
                VariableAssignmentInstr varAssInstr = cast(compiler.codegen.instruction.VariableAssignmentInstr)instruction;

                /* Value Instruction */
                Instruction valInstr = varAssInstr.data;

                /**
                * Process the expression (emitting code along the way)
                * and return the register the value will be placed in
                */
                Register valueRegister = emitAndProcessExpression(valInstr);


                /* Recursively descend soon */


                
                /* TODO: */

                /* Calculate the offset to be written to */
                ulong variableStackOffset = getVariableOffset(varAssInstr.varName);

                /* Find the variable being assigned to (TODO) */
                // Variable variable = 

                /* Calculate the amount to be written to said offset (TODO) */
                ulong writeSize = 0;
                
                // writeln("int "~varDecInstr.varName~";");

                /* TODO: Emit assignment to var */
                /* TODO: free->> valueRegister */
            }
            
        }

        /* Restore D info */
        restoreDInfo();

        /* Close the module */
        closeModule();
    }

    /**
    * Writes the given `data` of `size` to the addresses of
    * %rbp-|rbpOffsetMagnitude| at a stride of size
    */
    private void writeStackVar(ulong rbpOffsetMagnitutde, ubyte size, ulong data)
    {

    }

    /**
    * Same as `writeStackVar` but does muiltiple writes given a base address
    *
    * This is just to neaten up code (see this as a helper function as that is
    * all that it really is)
    */
    private void writeStackVarMulti(ulong rbOffsetMagBase, ubyte[] sizes, ulong[] datas)
    {

    }

    private void emitIninitailModule()
    {
        /* TODO: Maybe emit as d name */
        file.writeln("module "~typeChecker.getModule().getName()~";");
        file.writeln("void main()");
        file.writeln("{");
    }

    private void closeModule()
    {
        /* Restore for D exit */

        file.writeln(`
        int h = -1;
        h = *((&h)-4);
        import std.stdio;
        writeln(h);
        `);
        file.writeln("}");
    }
}