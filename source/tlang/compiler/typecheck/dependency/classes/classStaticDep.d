module tlang.compiler.typecheck.dependency.classes.classStaticDep;

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
import std.conv : to;

public class ClassStaticNode : DNode
{
    private Clazz entity;

    this(Clazz entity)
    {
        super(entity);

        this.entity = entity;
        initName();
    }

    private void initName()
    {
        name = "ClassStaticInit: "~to!(string)(entity);
    }
}