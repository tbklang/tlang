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

// TODO: Add an interface for MStatementSearchable which will allow
// ... us to search for a Statement anywhere in the tree. Useful, 
// ... over plane resolution as we may want to find Expression's
// ... which are not Entity's meaning they have no name. We need
// ... a "searchByType" that can find us all such types of statements
// ... within the tree.
// 
// For example, `searchByType(Expression)` on a `Variable` should
// search it's `VariableAssigmment` and return the `Expression`.
//
// This might require a static helper method in `MStatementSearchable`,
// that can be used then on known things like `Expression`'s sub-types
// such as BinaryOperator to search left-and-right.
//
// Thing is we need to do this in a non-instrusive manner. Mmmh, perhaps
// this is not the best way - not sure though.
//
// Okay, NO. Let's rather make a searcher ourselves honestly. I think it
// ... would be a lot easier to support these things ourselves. NO!
// ... Here is the problem however, replacing of items? ACTUALLY, we can
// ... still do that but damn an interface COULD help
public interface MStatementSearchable
{
    /** 
     * Search for a kind-of `Statement` by its type and return a referenced variable
     * (a `ref`) to it
     *
     * Params:
     *   statementType = the type of `Statemen` to look for
     *
     * Returns: a referenced variable to the found entity
     */
    public ref Statement search(TypeInfo_Class statementType);
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