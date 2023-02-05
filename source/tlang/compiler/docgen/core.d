module tlang.compiler.docgen.core;

import tlang.compiler.parsing.core;

public final class DocumentGenerator
{
    private Parser parser;

    this(Parser parser)
    {
        this.parser = parser;
    }

    /** 
     * TODO: Later remove vibed even, and have maybe our own implementation
     * just so we cna keep this more pure and less, well, whatever vibe-d is
     * licensed under
     */
    public void serve()
    {

    }
}