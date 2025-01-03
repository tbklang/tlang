/**
 * String management
 *
 * Tooling for managing string literals
 */
module tlang.compiler.typecheck.strings;

import niknaks.containers : Pool;
import tlang.compiler.symbols.strings;

public struct StringNode
{
    // TODO: Add rolling thing here?
    private string _s;
    this(StringExpression s_expr)
    {
        // this._s = s_expr.getStringLiteral();
    }
}

public alias StringPool = Pool!(StringNode, StringExpression);


public struct StringNode2
{
    private string _data;
    private Object _meta;

    private this(string data)
    {

    }

    // TODO: Implement hash and oequals
}

public struct StringManager
{
    
}