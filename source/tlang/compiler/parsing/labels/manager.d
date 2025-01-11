module tlang.compiler.parsing.labels.manager;

import tlang.compiler.parsing.labels.types;
import std.string : format;

public final class LabelManager
{
    private Label[string] _lbls;

    this()
    {

    }

    public void addLabel(string name)
    {
        Label* potLbl = name in _lbls;
        if(potLbl !is null)
        {
            throw new LabelException(format("The label %s already exists", name));
        }
    }
}