module tlang.compiler.typecheck.dependency.pool.impls;

import tlang.compiler.typecheck.dependency.pool.interfaces;
import tlang.compiler.typecheck.dependency.core : DNode, DNodeGenerator;
import tlang.compiler.typecheck.dependency.expression : ExpressionDNode;
import tlang.compiler.typecheck.dependency.variables : VariableNode, FuncDecNode, StaticVariableDeclaration, ModuleVariableDeclaration;
import tlang.compiler.typecheck.dependency.classes.classStaticDep : ClassStaticNode;

import tlang.compiler.symbols.data : Statement, Expression, Variable, Function, Clazz;
import std.traits : isAssignable;

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
     * Constructs a new pooling manager
     */
    this()
    {
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
        return poolT!(DNode, Statement)(statement);
    }

    /** 
     * Pools the provided `Clazz`
     * AST node but with an additional
     * check that it should match
     * against a `ClassStaticNode`
     * and if one does not exist
     * then one such dependency
     * node should be created
     *
     * Params:
     *   clazz = the class to statcally
     * pool
     * Returns: the pooled `ClassStaticNode`
     */
    public ClassStaticNode poolClassStatic(Clazz clazz)
    {
        foreach(DNode dnode; nodePool)
        {
            Statement entity = dnode.getEntity();
            if(entity == clazz && cast(ClassStaticNode)dnode)
            {
                return cast(ClassStaticNode)dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        ClassStaticNode newDNode = new ClassStaticNode(clazz);
        nodePool ~= newDNode;

        return newDNode;
    }

    /** 
     * Pools the provided `Expression`
     * AST node into an `ExpressionDNode`
     *
     * Params:
     *   expression = the AST node
     * Returns: the pooled `ExpressionDNode`
     */
    public ExpressionDNode poolExpression(Expression expression)
    {
        return poolT!(ExpressionDNode, Expression)(expression);
    }

    /** 
     * Pools the provided `Variable`
     * AST node into a `VariableNode`
     *
     * Params:
     *   variable = the AST node
     * Returns: the pooled `VariableNode`
     */
    public VariableNode poolVariable(Variable variable)
    {
        return poolT!(VariableNode, Variable)(variable);
    }

    /** 
     * Pools the provided `Variable`
     * AST node into a `StaticVariableDeclaration`
     *
     * Params:
     *   variable = the AST node
     * Returns: the pooled `StaticVariableDeclaration`
     */
    public StaticVariableDeclaration poolStaticVariable(Variable variable)
    {
        return poolT!(StaticVariableDeclaration, Variable)(variable);
    }

    /** 
     * Pools the provided `Variable`
     * AST node into a `ModuleVariableDeclaration`
     *
     * Params:
     *   variable = the AST node
     * Returns: the pooled `ModuleVariableDeclaration`
     */
    public ModuleVariableDeclaration poolModuleVariableDeclaration(Variable variable)
    {
        return poolT!(ModuleVariableDeclaration, Variable)(variable);
    }

    /** 
     * Pools the provided `Function`
     * AST node into a `FuncDecNode`
     *
     * Params:
     *   func = the AST node
     * Returns: the pooled `FUncDecNode`
     */
    public FuncDecNode poolFuncDec(Function func)
    {
        return poolT!(FuncDecNode, Function)(func);
    }

    /** 
     * Pools the provided AST node
     * to a dependency node, creating
     * one if one did not yet exist.
     *
     * This is a templatised version
     * which lets you specify the
     * kind-of `DNode` to be constructed
     * (if it does not yet exist) and
     * the incoming type of AST node.
     *
     * Params:
     *   entity = the AST node
     * Returns: the dependency node
     */
    public DNodeType poolT(DNodeType, EntityType)(EntityType entity)
    if(isAssignable!(DNode, DNodeType))
    {
        foreach(DNode dnode; nodePool)
        {
            if(dnode.getEntity() == entity)
            {
                return cast(DNodeType)dnode;
            }
        }

        /**
        * If no DNode is found that is associated with
        * the provided Entity then create a new one and
        * pool it
        */
        DNodeType newDNode = new DNodeType(entity);
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

    // Create a pool manager
    IPoolManager pool = new PoolManager();

    // Pool an AST node
    Variable astNode = new Variable("int", "age");
    DNode astDNode = pool.pool(astNode);

    // Now pool it (again) and ensure it matches
    // the dependency node just created
    assert(astDNode is pool.pool(astNode));
}