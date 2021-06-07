module compiler.typecheck.group;

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
        return "GroupInit ("~(cast(Entity)groupingEntity).getName()~"): "~to!(string)(initQueue);
    }
}

public final class Grouper
{
    // private TypeChecker tc;
    private Entity[] initQueue;

    this(Entity[] initQueue)
    {
        // this.tc = tc;
        this.initQueue = initQueue;
    }


Group[] groups;

        Entity[][Container] containers;
        Container[] keyOrder;

    private void groupToContainer(Container entityContainer, Entity entityToContain)
    {
        foreach(Container container; keyOrder)
        {
            if(container == entityContainer)
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
        

        foreach(Entity entity; initQueue)
        {
            /* The Container of the Entity */
            Container entityContainer = entity.parentOf();

            groupToContainer(entityContainer, entity);
        }

        foreach(Container container; keyOrder)
        {
            groups ~= new Group(container, containers[container]);
        }

        return groups;
    }
}