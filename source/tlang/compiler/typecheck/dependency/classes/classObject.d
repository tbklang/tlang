module tlang.compiler.typecheck.dependency.classes.classObject;

import tlang.compiler.symbols.check;
import tlang.compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import tlang.compiler.parsing.core;
import tlang.compiler.typecheck.resolution;
import tlang.compiler.typecheck.exceptions;
import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.typing.builtins;
import tlang.compiler.typecheck.dependency.core;

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

    this(Clazz objectActualType, NewExpression entity)
    {
        super(entity);

        // this.newExpression = entity;
        this.clazz = objectActualType;

        initName();
    }

    private void initName()
    {
        name = "new "~clazz.getName()~"()";
    }
}