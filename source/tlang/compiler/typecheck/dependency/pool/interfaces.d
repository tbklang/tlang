module tlang.compiler.typecheck.dependency.pool.interfaces;

import tlang.compiler.typecheck.dependency.core : DNode;
import tlang.compiler.symbols.data : Statement;
import std.traits : isAssignable;

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

    /** 
     * Pools the provided AST node
     * to a dependency node
     *
     * This version is templatised
     * in that it lets you specify
     * the type of `DNode` you want
     * to construct (in the case it
     * does not yet exist in the
     * pool) and also the type
     * of AST node going in
     *
     * Params:
     *   entity = the AST node
     * Returns: the pooled `DNodeType`
     */
    public DNodeType poolT(DNodeType, EntityType)(EntityType entity)
    if(isAssignable!(DNode, DNodeType));
}