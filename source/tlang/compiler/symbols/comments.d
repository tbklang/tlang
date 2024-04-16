module tlang.compiler.symbols.comments;

// TODO: Add comment parsing

import std.string : startsWith, split, strip, stripLeft;
import std.array : join;

private class CommentParser
{
    private string source;
    this(string source)
    {
        this.source = source;
    }

    private string commentPart;

    private string extract()
    {
        string buildUp;

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

            // Now put it all together in a new-line seperate string
            buildUp = join(lines, "\n");
        }

        return buildUp;
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
    string comment = parser.extract();

    writeln(format("Comment: '%s'", comment));

    // *cast(int*)0  = 1;
    assert(" Hello\n  there" == comment);
}

/** 
 * Represents a comment
 * which can be attached
 * to a `Statement`
 */
public final class Comment
{
    private string content;

    this(string content)
    {
        // TODO: Parse the comment into text but annotated section
        this.content = content;
    }

    public string getContent()
    {
        return this.content;
    }
}