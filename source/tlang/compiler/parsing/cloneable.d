module tlang.compiler.parsing.cloneable;

import tlang.compiler.symbols.data : Statement;

/** 
 * A parse-node/AST-node which implements `Cloneable` can
 * be safely deeply cloned such that a full copy is returned.
 */
public interface Cloneable
{
    /** 
     * Performs a deep clone of this parse node
     *
     * Returns: the clone
     */
    public Statement clone();
}