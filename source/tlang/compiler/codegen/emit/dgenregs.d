module compiler.codegen.emit.dgenregs;

import compiler.codegen.emit.core : CodeEmitter;
import compiler.typecheck.core;
import std.container.slist : SList;
import compiler.codegen.instruction;
import std.stdio;
import std.file;
import std.conv : to;
import std.string : cmp;


public abstract class Register
{
    public abstract bool isInUse();
    public abstract string getUsableName();

    public abstract void allocate(ubyte size);
    public abstract ubyte[] getSupportedSizes();

    public abstract void deallocate();
}

/**
* Support for x86_64's R8-R14 (R15 excluded for now)
*
* Example: R14B, R14W
*/
public final class RichardRegister : Register
{
    /* Which of the Richards? */
    private string richardBase;

    /* Current allocated size and name */
    private ubyte curSize;
    private string curName;

    /* State of usage */
    private bool inUse;

    /**
    * Construct a new RichardRegister with base
    * RX prefix
    */
    this(string XPrefix)
    {
        richardBase = "R"~XPrefix;
    }

    public override ubyte[] getSupportedSizes()
    {
        return [1,2,4,8];
    }

    public override void deallocate()
    {
        inUse = false;
    }

    public override void allocate(ubyte size)
    {
        curSize = size;
        inUse = true;
        
        if(size == 1)
        {       
            curName = richardBase~"B";
        }
        else if(size == 2)
        {       
            curName = richardBase~"W";
        }
        else if(size == 4)
        {       
            curName = richardBase~"D";
        }
        else if(size == 8)
        {       
            curName = richardBase~"";
        }
    }

    public override bool isInUse()
    {
        return inUse;
    }
}











