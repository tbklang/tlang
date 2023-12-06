module tlang.compiler.typecheck.dependency.pool.interfaces;

import tlang.compiler.typecheck.dependency.core : DNode;
import tlang.compiler.typecheck.dependency.expression : ExpressionDNode;
import tlang.compiler.typecheck.dependency.variables : VariableNode, FuncDecNode, StaticVariableDeclaration;

import tlang.compiler.symbols.data : Statement, Expression, Variable, Function;

// TODO: In future if we do not require the specific `ExpressionDNode` et al
// ... then remove them from the interface definition below

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
     * Pools the provided `Expression`
     * AST node into an `ExpressionDNode`
     *
     * Params:
     *   expression = the AST node
     * Returns: the pooled `ExpressionDNode`
     */
    public ExpressionDNode poolExpression(Expression expression);

    /** 
     * Pools the provided `Variable`
     * AST node into a `VariableNode`
     *
     * Params:
     *   variable = the AST node
     * Returns: the pooled `VariableNode`
     */
    public VariableNode poolVariable(Variable variable);

    /** 
     * Pools the provided `Variable`
     * AST node into a `StaticVariableDeclaration`
     *
     * Params:
     *   variable = the AST node
     * Returns: the pooled `StaticVariableDeclaration`
     */
    public StaticVariableDeclaration poolStaticVariable(Variable variable);

    /** 
     * Pools the provided `Function`
     * AST node into a `FuncDecNode`
     *
     * Params:
     *   func = the AST node
     * Returns: the pooled `FUncDecNode`
     */
    public FuncDecNode poolFuncDec(Function func);
}