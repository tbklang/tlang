module compiler.typecheck.classes.classObject;

import compiler.symbols.check;
import compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import compiler.parsing.core;
import compiler.typecheck.resolution;
import compiler.typecheck.exceptions;
import compiler.typecheck.core;
import compiler.symbols.typing.core;
import compiler.symbols.typing.builtins;
import compiler.typecheck.dependency;

/**
* (TODO) We don't init class in here, we do that when we see the type
* however, I would like to probably do it from here though
* as that means we can cut down on a lot of the code
*
* Level: Low
* Due date: End of year
*/
public class ObjectInitializationNode : DNode
{
    /* Object actual type */
    private Clazz clazz;

    this(DNodeGenerator dnodegen, Clazz objectActualType, NewExpression entity)
    {
        super(dnodegen, entity);

        // this.newExpression = entity;
        this.clazz = objectActualType;

        initName();
    }

    private void initName()
    {
        name = "new "~clazz.getName()~"()";
    }
}