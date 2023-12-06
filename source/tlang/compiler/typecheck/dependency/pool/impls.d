module tlang.compiler.typecheck.dependency.pool.impls;

import tlang.compiler.typecheck.dependency.pool.interfaces;
import tlang.compiler.typecheck.dependency.core : DNode, DNodeGenerator;
import tlang.compiler.symbols.data : Statement;

/** 
 * Provides an implementation of
 * the `IPoolManager` interface
 * such that you can use this
 * as part of the  dependency
 * generation process
 */
public final class PoolManager : IPoolManager
{
    /** 
     * The pool itself
     */
    private DNode[] nodePool;

    /** 
     * The dependency generator
     */
    private DNodeGenerator generator;

    /** 
     * Constructs a new pooling manager
     * with the provide dependency node
     * generator
     *
     * Params:
     *   generator = the `DNodeGenerator`
     */
    this(DNodeGenerator generator)
    {
        this.generator = generator;
    }

    /** 
     * Pools the provided AST node
     * to a dependency node, creating
     * one if one did not yet exist
     *
     * Params:
     *   statement = the AST node
     * Returns: the dependency node
     */
    public DNode pool(Statement statement)
    {
        foreach(DNode dnode; nodePool)
        {
            if(dnode.getEntity() == statement)
            {
                return dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Statement then create a new one
        * and pool it
        */
        DNode newDNode = new DNode(this.generator, statement);
        nodePool ~= newDNode;

        return newDNode;
    }
}

version(unittest)
{
    import tlang.compiler.symbols.data : Module, Variable;
    import tlang.compiler.typecheck.core : TypeChecker;
}

/**
 * Tests the pooling of AST nodes
 * to dependency nodes using the
 * `PoolManager` implementation
 */
unittest
{
    // Create bogus module and type checker
    Module testModule = new Module("myModule");
    TypeChecker tc = new TypeChecker(testModule);

    // Create a bogus dnode generator
    DNodeGenerator gen = new DNodeGenerator(tc);

    // Create a pool manager
    IPoolManager pool = new PoolManager(gen);

    // Pool an AST node
    Variable astNode = new Variable("int", "age");
    DNode astDNode = pool.pool(astNode);

    // Now pool it (again) and ensure it matches
    // the dependency node just created
    assert(astDNode is pool.pool(astNode));
}