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
     */
    public void replace(Statement thiz, Statement that);
}

public class Repr : Expression
{
    /** 
     * TODO: Add a MStatementSearchable implementation
     */
}



// FIXME: Make this inherit from IntegerLiteral and also,
// make `getLiteral/number` overridable such that we can
// actually evaluate it depending on the identifier (type)
// and return the type's size
public class Sizeof : IntegerLiteral, MTypeRewritable
{
    /** 
     * The identifier to apply sizeof to
     *
     * Example: `sizeof(uint)`
     */
    private string identifier;

    this(string identifier)
    {
        super("SIZEOF_NUMBER_LITERAL_NOT_YET_SET", IntegerLiteralEncoding.UNSIGNED_INTEGER);
    }

    public void setType(string identifier)
    {
        this.identifier = identifier;
    }

    public string getType()
    {
        return identifier;
    }
}