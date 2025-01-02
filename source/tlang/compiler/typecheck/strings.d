/**
 * String management
 *
 * Tooling for managing string literals
 */
module tlang.compiler.typecheck.strings;

import niknaks.containers : Pool;
import tlang.compiler.symbols.expressions : StringExpression;

public struct StringNode
{
    // TODO: Add rolling thing here?
    private string _s;
    this(StringExpression s_expr)
    {
        this._s = s_expr.getStringLiteral();
    }
}

public alias StringPool = Pool!(StringNode, StringExpression);