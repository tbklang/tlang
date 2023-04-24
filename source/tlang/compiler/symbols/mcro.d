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