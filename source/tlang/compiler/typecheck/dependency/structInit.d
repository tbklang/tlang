module tlang.compiler.typecheck.dependency.structInit;

import tlang.compiler.symbols.containers : Container, Struct;
import tlang.compiler.symbols.data : Entity;
import tlang.compiler.typecheck.dependency.core;

/** 
 * Represents the instantiation of a struct-typed
 * variable
 */
public final class StructInstanceInit : DNode
{
    /** 
     * Constructs a new `StructInstanceInit`
     * which represents the instantiation
     * of a new instance of the provided
     * `Struct`
     *
     * Params:
     *   dnodegen = the `DNodeGenerator`
     *   toInit = the `Struct` being instantiated
     */
    this(DNodeGenerator dnodegen, Struct toInit)
    {
        super(dnodegen, toInit);
        initName();
    }

    /** 
     * Returns the metadata on the struct that is
     * to be instantiated
     *
     * Returns: the metadata as a `Struct`
     */
    public Struct getMetadata()
    {
        return cast(Struct)getEntity();
    }

    private void initName()
    {
        name = "StructInstantiate: "~resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }
}