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

    /** 
     * Searches to see if a given AST
     * node is present.
     *
     * This basically uses the type
     * of the node to search,
     * then filters based on that.
     *
     * Params:
     *   statement = the AST node
     * Returns: `true` if found,
     * `false` otherwise
     */
    public final bool isPresent(Statement statement)
    {
        Statement[] typeMatches = search(statement.classinfo);
        foreach(Statement stmt; typeMatches)
        {
            if(stmt == statement)
            {
                return true;
            }
        }

        return false;
    }
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