/**
 * Type remapping
 *
 * Support for the type remapping AST type:
 *
 * ```
 * type b = int;
 * type a = b;
 * ```
 *
 * These are named entities which store
 * a pair of values (string, string);
 * the first being the remapped type's name
 * and the second being the type to refer
 * to.
 *
 * The weighting is set to 1 so that this
 * gets re-ordered to appear before variable
 * declarations (i.e. where they would be
 * used for example)
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.remaps;

import tlang.compiler.symbols.typing.core : Type;
import std.string : format;

public final class TypeAlias : Type
{
    private string _mt;

    this(string remappedName, string mappedTo)
    {
        super(remappedName);
        this.weight = 1;
        this._mt = mappedTo;
    }

    public override string toString()
    {
        return format("TypeAlias [name: %s, mappedTo: %s]", getName(), _mt);
    }

    public string getReferentType()
    {
        return this._mt;
    }
}