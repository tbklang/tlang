module tlang.compiler.typecheck.dependency.expression;

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

public class ExpressionDNode : DNode
{
    this(DNodeGenerator dnodegen, Expression entity)
    {
        super(dnodegen, entity);

        initName();
    }

    private void initName()
    {
        name = "[expression: "~entity.toString()~"]";
    }
}

// public class LiteralDNode : ExpressionDNode
// {
//     this(DNodeGenerator dnodegen, Expression entity)
//     {
//         super(dnodegen, entity);

//         // initName();
//     }

//     private void initName()
//     {
//         name = "[literal: "~entity.toString()~"]";
//     }
// }

/**
* AccessNode
*
* An AccessNode represents a accessor call
* This can be as simple as `a` or `a.a`
*/
public class AccessDNode : DNode
{
    /**
    * Construct a new AccessNode given the `entity`
    * being accessed
    */
    this(DNodeGenerator dnodegen, Entity entity)
    {
        super(dnodegen, entity);
        // this.entity = entity;


        initName();
    }

    private void initName()
    {
        name = resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
        name = "[AccessNode] (Name: "~name~")";
        
    }
}