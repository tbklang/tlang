module tlang.compiler.typecheck.dependency.classes.classVirtualInit;

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

public class ClassVirtualInit : DNode
{
    this(DNodeGenerator dnodegen, Clazz clazz)
    {
        super(dnodegen, clazz);
    }
}