/**
 * Label manager
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.parsing.labels.manager;

import tlang.compiler.parsing.labels.types;
import std.string : format;
import niknaks.functional : Optional;

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

        _lbls[name] = Label(name);
    }

    public Optional!(Label*) getLabel(string name)
    {
        Label* potLbl = name in _lbls;
        return potLbl ? Optional!(Label*)(potLbl) : Optional!(Label*).empty();
    }
}