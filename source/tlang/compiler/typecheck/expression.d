module compiler.typecheck.expression;

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

public final class ExpressionDNode : DNode
{
    private Expression expression;

    this(DNodeGenerator dnodegen, Expression entity)
    {
        super(dnodegen, entity);
        this.expression = expression;

        initName();
    }

    private void initName()
    {
        name = "[expression]";
    }
}