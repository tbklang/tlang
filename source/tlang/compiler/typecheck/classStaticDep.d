module compiler.typecheck.classStaticDep;

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

public class ClassStaticNode : DNode
{
    this(DNodeGenerator dnodegen, Clazz entity)
    {
        super(dnodegen, entity);
    }
}