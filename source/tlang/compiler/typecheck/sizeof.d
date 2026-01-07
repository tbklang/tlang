/**
 * Support for `sizeof()`
 *
 * Provides tooling related to working with `sizeof(ident)
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.typecheck.sizeof;

import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.symbols.expressions : Expression, IntegerLiteral, IntegerLiteralEncoding;
import tlang.compiler.symbols.typing.core;

import std.conv : to;

public IntegerLiteral determineSizeOfLiteral
(
    TypeChecker tc,
    Container from,
    string typeName
)
{
    IntegerLiteral literal = new IntegerLiteral("TODO_LITERAL_GOES_HERESIZEOF_REPLACEMENT", IntegerLiteralEncoding.UNSIGNED_INTEGER);

    // TODO: Via typechecker determine size with a lookup
    Type type = tc.getType(from, typeName);

    /* Calculated type size */
    ulong typeSize = 0;

    /**
        * Calculate stack array size
        *
        * Algo: `<componentType>.size * stackArraySize`
        */
    if(cast(StackArray)type)
    {
        StackArray stackArrayType = cast(StackArray)type;
        ulong arrayLength = stackArrayType.getAllocatedSize();
        Type componentType = stackArrayType.getComponentType();
        ulong componentTypeSize = 0;
        
        // FIXME: Later, when the Dependency Genrator supports more advanced component types,
        // ... we will need to support this - for now assume that `componentType` is primitive
        if(cast(Number)componentType)
        {
            Number numberType = cast(Number)componentType;
            componentTypeSize = numberType.getSize();
        }

        typeSize = componentTypeSize*arrayLength;
    }
    /**
        * Calculate the size of `Number`-based types
        */
    else if(cast(Number)type)
    {
        Number numberType = cast(Number)type;
        typeSize = numberType.getSize();
    }

    // TODO: We may eed toupdate Type so have bitwidth or only do this
    // for basic types - in which case I guess we should throw an exception
    // here.
    // ulong typeSize = 

    

    /* Update the `Sizeof` kind-of-`IntegerLiteral` with the new size */
    literal.setNumber(to!(string)(typeSize));

    return literal;
}