module tlang.compiler.symbols.comments;

// TODO: Add comment parsing

import std.string : startsWith, split, strip, stripLeft, stripRight;
import std.array : join;

import tlang.misc.logging;
import std.string : format;

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

    public enum DocType getType()
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

private struct CommentParts
{
    string bdy;
    DocStr[] strs;
}

private class CommentParser
{
    private string source;
    this(string source)
    {
        this.source = source;
    }

    private string commentPart;

    private CommentParts extract()
    {
        CommentParts parts;

        // Handle multi-line comments
        if(this.source.startsWith("/**"))
        {
            string[] lines = split(this.source, "\n");

            // Strip all lines of any white space on the left-hand or right-hand margins
            for(ulong i = 0; i < lines.length; i++)
            {
                lines[i] = strip(lines[i]);
            }

            // Strip first line of the `/**`
            lines[0] = stripLeft(lines[0], "/**");

            // Strip all lines between the starting and ending delimiter
            // of their `*`s
            for(ulong i = 1; i < lines.length-1; i++)
            {
                lines[i] = stripLeft(lines[i], "*");

            }

            // Strip last line of a a `*/`
            lines[lines.length-1] = stripLeft(lines[lines.length-1], "*/");

            version(unittest)
            {
                import niknaks.debugging;
                import std.stdio : writeln;
                writeln(dumpArray!(lines));
                
            }

            // Now get rid of the first line if it is empty
            if(lines[0].length == 0)
            {
                lines = lines[1..$];
            }

            // Get rid of the last line if it is empty
            if(lines[$-1].length == 0)
            {
                lines = lines[0..$-1];
            }

            // Set the body parts
            parts.bdy = join(stripOutDocLines(lines));

            // Set doc strings
            DocStr[] docStrs;
            foreach(string line; onlyParams(lines))
            {
                DocStr ds;

                if(extractDocLine(line, ds))
                {
                    docStrs ~= ds;
                    DEBUG(format("Converted docline '%s' to: %s", line, ds));
                }
            }
            parts.strs = docStrs;
        }
        // Handle single-line comments
        else
        {
            // Set body parts
            parts.bdy = strip(stripLeft(this.source, ("//")));
        }

        return parts;
    }

    private bool extractDocLine(string line, ref DocStr ds)
    {
        string buildUp;
        bool foundType = false;

        ulong i = 0;
        bool getch(ref char c)
        {
            if(i < line.length)
            {
                c = line[i];
                return true;
            }
            return false;
        }

        void prog()
        {
            i++;
        }

        char c;


        bool parseParam(ref string paramName, ref string paramDescription)
        {
            bool gotParamName = false;
            string foundParamName;
            bool gotParamDescription = false;
            string foundParamDescription;

            while(getch(c))
            {
                if(c == ' ')
                {
                    prog;
                    continue;
                }
                else if(!gotParamName)
                {
                    while(getch(c) && c != ' ')
                    {
                        foundParamName ~= c;
                        prog;
                    }

                    // TODO: Validate name?
                    gotParamName = true;
                }
                else
                {
                    while(getch(c))
                    {
                        foundParamDescription ~= c;
                        prog;
                    }

                    gotParamDescription = true;
                }
            }

            if(gotParamName && gotParamDescription)
            {
                paramName = foundParamName;
                paramDescription = foundParamDescription;

                return true;
            }
            else
            {
                return false;
            }
        }

        bool parseReturn(ref string returnDescription)
        {
            string gotDescription;
            bool foundDescription;
            while(getch(c))
            {
                if(c == ' ' && !foundDescription)
                {
                    prog;
                    continue;
                }

                gotDescription ~= c;
                prog;
                foundDescription = true;
            }

            if(foundDescription)
            {
                returnDescription = gotDescription;
                return true;
            }
            else
            {
                return false;
            }
        }

        
        while(getch(c))
        {
            if(c == ' ')
            {
                prog();
                continue;
            }
            else if(c == '@' && !foundType)
            {
                string paramType;
                prog();
                while(getch(c) && c != ' ')
                {
                    paramType ~= c;
                    prog();
                }

                // @param
                if(paramType == "param")
                {
                    string paramName, paramDescr;
                    if(parseParam(paramName, paramDescr))
                    {
                        ds = DocStr.param(paramName, paramDescr);
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
                // @return
                else if (paramType == "return")
                {
                    string returnDescr;
                    if(parseReturn(returnDescr))
                    {
                        ds = DocStr.returns(returnDescr);
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
                // @throws
                else if(paramType == "throws")
                {
                    string exceptionName, exceptionDescr;
                    if(parseParam(exceptionName, exceptionDescr)) // Has same structure as a `@param <1> <...>`
                    {
                        ds = DocStr.exception(exceptionName, exceptionDescr);
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
                // Unknown @<thing>
                else
                {
                    return false;
                }
            }
            else
            {
                return false;
            }
        }

        return false;
    }

    // TODO: Use niknaks filter
    private string[] onlyParams(string[] input)
    {
        string[] withDoc;

        foreach(string i; input)
        {
            if(stripLeft(i).startsWith("@"))
            {
                withDoc ~= i;
            }
        }

        return withDoc;
    }

    // TODO: Use niknaks filter
    private string[] stripOutDocLines(string[] input)
    {
        string[] withoutDoc;

        foreach(string i; input)
        {
            DEBUG(format("'%s'", i));
            if(!stripLeft(i).startsWith("@"))
            {
                // Strip left-hand side of any spaces
                // and add trailing space
                withoutDoc ~= stripLeft(i)~' ';
            }
        }

        // Remove trailing whitespace on last item
        if(withoutDoc.length)
        {
            withoutDoc[$-1] = stripRight(withoutDoc[$-1]);
        }

        return withoutDoc;
    }
}


version(unittest)
{
    import std.stdio;
    import std.string : format;
}

unittest
{
    // It will NEVER start with a ' ' due to how it is tokenized
    string source = `/**
 * Hello
 *  there
 */`;
    CommentParser parser = new CommentParser(source);
    CommentParts comment = parser.extract();

    writeln(format("Comment: '%s'", comment));

    // *cast(int*)0  = 1;
    assert("Hello there" == comment.bdy);
}

import tlang.compiler.lexer.core.tokens : Token;

/** 
 * Represents a comment
 * which can be attached
 * to a `Statement`
 */
public final class Comment
{
    private CommentParts content;

    private this(CommentParts content)
    {
        // TODO: Parse the comment into text but annotated section
        this.content = content;
    }

    public static Comment fromToken(Token commentToken)
    {
        return fromText(commentToken.getToken());
    }

    private static Comment fromText(string text)
    {
        // TODO: Inline this behavior here
        CommentParser parser = new CommentParser(text);

        return new Comment(parser.extract());
    }

    public string getContent()
    {
        return this.content.bdy;
    }

    public DocStr[] getDocStrings()
    {
        return this.content.strs;
    }

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