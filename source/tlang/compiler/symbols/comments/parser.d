/** 
 * Implementation of the comment parser
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.comments.parser;

import std.string : startsWith, split, strip, stripLeft, stripRight;
import std.array : join;
import tlang.misc.logging;
import tlang.compiler.symbols.comments.types;
import std.string : format;

/** 
 * Parts of a comment
 */
public struct CommentParts
{
    string bdy;
    DocStr[] strs;
}

/** 
 * Parses comments of various forms
 */
public class CommentParser
{
    /** 
     * Comment text
     */
    private string source;

    /** 
     * Constructs a new `CommentParser`
     * which can extract the comments
     * from the given comment text
     *
     * Params:
     *   source = the comment itself
     */
    this(string source)
    {
        this.source = source;
    }

    /** 
     * Begins the parsing of the provided
     * comment source text.
     *
     * This assumes a well-formatted
     * comment is passed to us. i.e. one
     * extracted form the lexer.
     *
     * Returns: the `CommentParts`
     */
    public CommentParts extract()
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

            // Strip first line of the `/`
            lines[0] = stripLeft(lines[0], "/");

            // Strip last line of the `/`
            lines[$-1] = stripRight(lines[$-1], "/");

            // Strip all lines of `*` (on either side)
            for(ulong i = 0; i < lines.length; i++)
            {
                lines[i] = strip(lines[i], "*");
            }

            

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

    /** 
     * Attempts to extract the doc params
     * from a given line, returning if it
     * was a success or not
     *
     * Params:
     *   line = the line to parse
     *   ds = the result (if any)
     * Returns: `true` if extraction succeeded,
     * otherwise `false`
     */
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


        bool spacey(char c)
        {
            return c == ' ' || c == '\t';
        }

        bool parseParam(ref string paramName, ref string paramDescription)
        {
            bool gotParamName = false;
            string foundParamName;
            bool gotParamDescription = false;
            string foundParamDescription;

            while(getch(c))
            {
                if(spacey(c))
                {
                    prog;
                    continue;
                }
                else if(!gotParamName)
                {
                    while(getch(c) && !spacey(c))
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
                if(spacey(c) && !foundDescription)
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
            if(spacey(c))
            {
                prog();
                continue;
            }
            else if(c == '@')
            {
                string paramType;
                prog();
                while(getch(c) && !spacey(c))
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
                    WARN(format("Unknown docstring type '%s'", paramType));
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

    /** 
     * Strips out all lines with doc-strings
     * (params) in them
     *
     * Params:
     *   input = the input lines
     * Returns: the output lines
     */
    private string[] onlyParams(string[] input)
    {
        string[] withDoc;

        // TODO: Use niknaks filter
        foreach(string i; input)
        {
            if(stripLeft(i).startsWith("@"))
            {
                withDoc ~= i;
            }
        }

        return withDoc;
    }

    /** 
     * Strips out any line which is a doc line
     * (non-parameter line)
     *
     * Params:
     *   input = the input lines
     * Returns: the output lines
     */
    private string[] stripOutDocLines(string[] input)
    {
        string[] withoutDoc;

        // TODO: Use niknaks filter
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

    assert("Hello there" == comment.bdy);
}