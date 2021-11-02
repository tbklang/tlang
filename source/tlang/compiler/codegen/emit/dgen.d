module compiler.codegen.emit.dgen;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;



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
                        mov byte ptr [RSP], 69;
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
                        mov word ptr [RSP], 69;
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
                        mov dword ptr [RSP], 69;
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
                        mov qword ptr [RSP], 69;
                    }
                    `);
                }
                
                
                /* TODO: We need to build map of stakc positions, maybe not */
            }
            /**
            * compiler.codegen.instruction.VariableAssignmentInstr
            */
            else if(cast(VariableAssignmentInstr)instruction)
            {
                VariableAssignmentInstr varAssInstr = cast(compiler.codegen.instruction.VariableAssignmentInstr)instruction;

                

                /* Recursively descend soon */
                
                // writeln("int "~varDecInstr.varName~";");
            }
            
        }

        /* Restore D info */
        restoreDInfo();

        /* Close the module */
        closeModule();
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