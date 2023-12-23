module tlang.compiler.typecheck.dependency.declarables;

import tlang.compiler.symbols.containers : Container, Struct;
import tlang.compiler.symbols.data : Entity;
import tlang.compiler.typecheck.dependency.core;

/** 
 * Represents the requirement to declare a
 * struct-based type
 */
public final class StructTypeDeclarable : DNode
{
    /** 
     * Constructs a new `StructTypeDeclarable`
     * which represents the declaration
     * of a `Struct`-based type
     *
     * Params:
     *   dnodegen = the `DNodeGenerator`
     *   typeToDeclare = the `Struct` type
     */
    this(DNodeGenerator dnodegen, Struct typeToDeclare)
    {
        super(dnodegen, typeToDeclare);
        initName();
    }

    /** 
     * Returns the actual `Type`
     *
     * Returns: the type to declare
     */
    public Struct getType()
    {
        return cast(Struct)getEntity();
    }

    /** 
     * Gets the number of members of the
     * struct being initialized.
     *
     * Useful for when doing the code
     * generation pass.
     *
     * Returns: the number of members
     */
    public ulong getMemberCount()
    {
        return (cast(Container)entity).getStatements().length;
    }

    private void initName()
    {
        name = "StructTypeDeclare: "~resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }

    public override string toString()
    {
        return name;
    }
}