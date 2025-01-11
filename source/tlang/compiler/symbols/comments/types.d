/** 
 * Type definitions related to comments
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.comments.types;

import tlang.compiler.symbols.comments.parser;
import tlang.compiler.lexer.core.tokens : Token;

/** 
 * The type of docstring
 */
public enum DocType
{
    /** 
     * A parameter docstring
     *
     * This documents a function's
     * parameter
     */
    PARAM,

    /** 
     * An exception docstring
     *
     * This documents a function's
     * exceptions which is throws
     */
    THROWS,

    /** 
     * A return docstring
     *
     * This documents a cuntion's
     * return type
     */
    RETURNS
}

/** 
 * A parameter docstring
 *
 * This documents a function's
 * parameter
 */
public struct ParamDoc
{
    private string param;
    private string description;

    public string getParam()
    {
        return this.param;
    }

    public string getDescription()
    {
        return this.description;
    }
}

/** 
 * A return docstring
 *
 * This documents a cuntion's
 * return type
 */
public struct ReturnsDoc
{
    private string description;

    public string getDescription()
    {
        return this.description;
    }
}

/** 
 * An exception docstring
 *
 * This documents a function's
 * exceptions which is throws
 */
public struct ExceptionDoc
{
    private string exception;
    private string description;

    public string getException()
    {
        return this.exception;
    }

    public string getDescription()
    {
        return this.description;
    }
}

/** 
 * Union to be able
 * to reinterpret cast
 * any of the members
 * listed below
 */
private union DocContent
{
    ParamDoc param;
    ReturnsDoc returns;
    ExceptionDoc exception;
}

/** 
 * Represents a docstring
 * comprised of a type
 * and the docstring itself
 */
public struct DocStr
{
    private DocType type;
    private DocContent content;

    public DocType getType()
    {
        return this.type;
    }

    public static DocStr param(string name, string description)
    {
        DocStr dstr;
        dstr.type = DocType.PARAM;
        dstr.content.param = ParamDoc(name, description);
        return dstr;
    }

    public static DocStr returns(string description)
    {
        DocStr dstr;
        dstr.type = DocType.RETURNS;
        dstr.content.returns = ReturnsDoc(description);
        return dstr;
    }

    public static DocStr exception(string name, string description)
    {
        DocStr dstr;
        dstr.type = DocType.THROWS;
        dstr.content.exception = ExceptionDoc(name, description);
        return dstr;
    }

    public bool getExceptionDoc(ref ExceptionDoc doc)
    {
        if(this.type == DocType.THROWS)
        {
            doc = content.exception;
            return true;
        }

        return false;
    }

    public bool getParamDoc(ref ParamDoc doc)
    {
        if(this.type == DocType.PARAM)
        {
            doc = content.param;
            return true;
        }

        return false;
    }

    public bool getReturnDoc(ref ReturnsDoc doc)
    {
        if(this.type == DocType.RETURNS)
        {
            doc = content.returns;
            return true;
        }

        return false;
    }
}

/** 
 * Represents a comment
 * which can be attached
 * to a `Statement`
 */
public final class Comment
{
    /** 
     * The comment's component
     * parts
     */
    private CommentParts content;

    /** 
     * Constructs a new comment out
     * of its parsed component parts
     *
     * Params:
     *   content = the parts
     */
    private this(CommentParts content)
    {
        this.content = content;
    }

    /** 
     * Generates a comment from the 
     * provided token
     *
     * Params:
     *   commentToken = token containing
     * the comment
     * Returns: a `Comment`
     */
    public static Comment fromToken(Token commentToken)
    {
        return fromText(commentToken.getToken());
    }

    /** 
     * Generates a comment from the
     * provided comment text
     *
     * Params:
     *   text = the text containing
     * the comment
     * Returns: a `Comment`
     */
    private static Comment fromText(string text)
    {
        CommentParser parser = new CommentParser(text);
        return new Comment(parser.extract());
    }

    /** 
     * Extracts the comment's contents.
     *
     * This excludes param/doc-strings
     *
     * Returns: the contents
     */
    public string getContent()
    {
        return this.content.bdy;
    }

    /** 
     * Extract all the doc-strings present
     * within the comment
     *
     * Returns: an array of them
     */
    public DocStr[] getDocStrings()
    {
        return this.content.strs;
    }

    /** 
     * Extracts all of the param-docs
     * and places them into a key-value
     * mapping whereby the key is
     * the parameter's name and the
     * value the doc itself
     *
     * Returns: a map
     */
    public ParamDoc[string] getAllParamDocs()
    {
        // TODO: Use niknaks
        ParamDoc[string] d;
        foreach(DocStr i; getDocStrings())
        {
            if(i.type == DocType.PARAM)
            {
                ParamDoc pDoc = i.content.param;
                d[pDoc.param] = pDoc;
            }
        }

        return d;
    }

    /** 
     * Extracts the return doc-string
     * from this comment
     *
     * Params:
     *   retDoc = the found `ReturnDoc`
     * Returns: `true` if found, otheriwse
     * `false`
     */
    public bool getReturnDoc(ref ReturnsDoc retDoc)
    {
        // TODO: Use niknaks flter
        foreach(DocStr d; getDocStrings())
        {
            if(d.type == DocType.RETURNS)
            {
                retDoc = d.content.returns;
                return true;
            }
        }

        return false;
    }
}