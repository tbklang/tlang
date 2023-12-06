module tlang.compiler.typecheck.dependency.pool;

import tlang.compiler.typecheck.dependency.core : DNode;
import tlang.compiler.symbols.data : Statement;

/** 
 * Defines an interface by which
 * `Statement`s (i.e. AST nodes)
 * can be mapped to a `DNode`
 * and if one does not exist
 * then it is created on the
 * first use
 */
public interface IPoolManager
{
    /** 
     * Pools the provided AST node
     * to a dependency node
     *
     * Params:
     *   statement = the AST node
     * Returns: the pooled `DNode`
     */
    public DNode pool(Statement statement);
}