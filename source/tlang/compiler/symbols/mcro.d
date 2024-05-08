module tlang.compiler.symbols.mcro;

import tlang.compiler.symbols.data;

public class Macro : Statement
{

}

public interface MTypeRewritable
{
    public string getType();
    public void setType(string type);
}

/** 
 * Anything which implements this has the ability
 * to search for objects of the provided type,
 * and return a list of them
 */
public interface MStatementSearchable
{
    /** 
     * Searches for all objects of the given type
     * and returns an array of them. Only if the given
     * type is equal to or sub-of `Statement`
     *
     * Params:
     *   clazzType = the type to search for
     * Returns: an array of `Statement` (a `Statement[]`)
     */
    public Statement[] search(TypeInfo_Class clazzType);
}

/** 
 * Anything which implements this has the ability
 * to, given an object `x`, return a `ref x` to it
 * hence allowing us to replace it
 */
public interface MStatementReplaceable
{
    /**
     * Replace a given `Statement` with another `Statement`
     *
     * Params:
     *   thiz = the `Statement` to replace
     *   that = the `Statement` to insert in-place
     * Returns: `true` if the replacement succeeded, `false` otherwise
     */
    public bool replace(Statement thiz, Statement that);
}

/** 
 * Anything which implements this can make a full
 * deep clone of itself
 */
public interface MCloneable
{
    /** 
     * Returns a `Statement` which is a clone of this one
     * itself
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public Statement clone(Container newParent = null);
}

/** 
 * Any AST type which implements this
 * then will provide the ability to
 * compare the AST nodes within itself
 * (what that means is up to the implementing
 * node)
 */
public interface MComparable
{
    /** 
     * Compares the two nodes and reports
     * on the position of `thiz` relative
     * to `that`.
     *
     * Params:
     *   thiz = the first AST node
     *   that = the second AST node
     * Returns: a `Pos`
     */
    public Pos compare(Statement thiz, Statement that);

    /** 
     * Compares the two statements and returns
     * a value depending on which AST node
     * precedes the other.
     *
     * Params:
     *   thiz = the first AST node 
     *   that = the second AST node
     * Returns: `true` if `thiz` comes before
     * `that`, `false` otherwise
     */
    public final bool isBefore(Statement thiz, Statement that)
    {
        return compare(thiz, that) == Pos.BEFORE;
    }

    /** 
     * Compares the two statements and returns
     * a value depending on which AST node
     * proceeds the other.
     *
     * Params:
     *   thiz = the first AST node 
     *   that = the second AST node
     * Returns: `true` if `thiz` comes after
     * `that`, `false` otherwise
     */
    public final bool isAfter(Statement thiz, Statement that)
    {
        return compare(thiz, that) == Pos.AFTER;
    }

    public enum Pos
    {
        /**
         * If the position is the
         * first node coming before
         * the other
         */
        BEFORE,

        /**
         * If the position is the
         * first node coming after
         * the other
         */
        AFTER,

        /**
         * If both nodes are infact
         * the same node
         */
        SAME,

        /** 
         * To be returned on an error
         * dependant on implementation
         */
        ERROR
    }

}