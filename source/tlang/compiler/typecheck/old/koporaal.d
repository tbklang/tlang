module compiler.typecheck.old.koporaal;

import gogga;
import compiler.symbols.data;
import compiler.symbols.typing.core;
import compiler.typecheck.core;
import std.conv : to;
import compiler.parsing.core;
import compiler.typecheck.old.group;

/**
* Koporaal
*
* This is one step away from code generation, infact it almost is
* but it won't emit code, rather follow the dependency tree
*/
public class Koporaal
{
    /* The dependency tree */
    private Group[] groups;

    this(Group[] groups)
    {
        this.groups = groups;
    }

    private ulong i = 0;

    public void printInit()
    {
        foreach(Group group; groups)
        {
            Entity[] entities = group.getInitQueue();
            foreach(Entity entity; entities)
            {
                gprintln("Initialize ("~to!(string)(i)~"): "~entity.getName());
                i++;
            }
        }
    }
}