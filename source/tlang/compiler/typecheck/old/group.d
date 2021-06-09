module compiler.typecheck.old.group;

import gogga;
import compiler.symbols.data;
import compiler.symbols.typing.core;
import compiler.typecheck.core;
import std.conv : to;
import compiler.parsing.core;

public class Group
{
    private Container groupingEntity;
    private Entity[] initQueue;

    this(Container groupingEntity, Entity[] initQueue)
    {
        this.groupingEntity = groupingEntity;
        this.initQueue = initQueue;
    }

    public Container getGroupingEntity()
    {
        return groupingEntity;
    }

    public Entity[] getInitQueue()
    {
        return initQueue;
    }

    public override string toString()
    {
        return "GroupInit (" ~ (cast(Entity) groupingEntity)
            .getName() ~ "): " ~ to!(string)(initQueue);
    }
}

public final class Grouper
{
    // private TypeChecker tc;
    private Entity[] initQueue;
    private TypeChecker tc;

    this(TypeChecker tc, Entity[] initQueue)
    {
        this.tc = tc;
        this.initQueue = initQueue;
    }

    private Group[] groups;
    private Entity[][Container] containers;
    private Container[] keyOrder;

    private void groupToContainer(Container entityContainer, Entity entityToContain)
    {
        foreach (Container container; keyOrder)
        {
            if (container == entityContainer)
            {
                goto add_to_container;
            }
        }

        keyOrder ~= entityContainer;

    add_to_container:
        containers[entityContainer] ~= entityToContain;
    }

    /**
    *
    */
    public Group[] begin()
    {
        gprintln("Grouping beginning...");
        gprintln("GBegin: "~to!(string)(initQueue));

        foreach (Entity entity; initQueue)
        {
            /* The Container of the Entity */
            Container entityContainer = entity.parentOf();

            /* Dont' add Module's container (which would be null) */
            if(entityContainer is null)
            {
                /* This should only ever occur whern the Entity is a Module */
                assert(cast(Module)entity);
            }
            else
            {
                groupToContainer(entityContainer, entity);
            }
        }

        foreach (Container container; keyOrder)
        {
            groups ~= new Group(container, containers[container]);
        }

        return groups;
    }
}
