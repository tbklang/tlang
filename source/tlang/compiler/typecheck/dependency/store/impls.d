/** 
 * Provides implementation of the `IFuncDefStore`
 * interface
 */
module tlang.compiler.typecheck.dependency.store.impls;

import tlang.compiler.typecheck.dependency.store.interfaces;
import tlang.compiler.symbols.data : Function;
import tlang.compiler.typecheck.dependency.core : FunctionData, DFunctionInnerGenerator;
import tlang.compiler.typecheck.core : TypeChecker;
import tlang.compiler.typecheck.dependency.pool.interfaces : IPoolManager;

/** 
 * An implementation of the `IFuncDefStore`
 * which provides us with a way to store
 * function definitions and retrieve them
 * later
 */
public final class FuncDefStore : IFuncDefStore
{
    /**
     * All declared functions
     */
    private FunctionData[string] functions;

    /** 
     * The type checker instance
     */
    private TypeChecker tc;

    /** 
     * The pool management
     */
    private IPoolManager poolManager;

    /** 
     * Constructs a new function
     * definition store with
     * the provided type
     * checking instance
     *
     * Params:
     *   typeChecker = the `TypeChecker`
     *   poolManager = the `IPoolManager`
     */
    this(TypeChecker typeChecker, IPoolManager poolManager)
    {
        this.tc = typeChecker;
        this.poolManager = poolManager;
    }

    /** 
     * Adds the function definition
     * to the store
     *
     * Params:
     *   func = the function to add
     * Throws:
     *   FuncDefStoreException if the function
     * has already been added
     */
    public void addFunctionDef(Function func)
    {
        /* (Sanity Check) This should never be called again */
        foreach(string cFuncKey; functions.keys())
        {
            FunctionData cFuncData = functions[cFuncKey];
            Function cFunc = cFuncData.func;

            if(cFunc == func)
            {
                throw new FuncDefStoreException("The provided Function already exists within the store");
            }
        }

        /**
        * Create the FunctionData, coupled with it own DNodeGenerator
        * context etc.
        */
        FunctionData funcData;
        funcData.ownGenerator = new DFunctionInnerGenerator(tc, this.poolManager, this, func);
        // TODO: Should we not generate a HELLA long name rather, to avoid duplication problems and overwrites of key values

        funcData.name = tc.getResolver().generateName(tc.getProgram(), func);

        funcData.name = func.getName();
        funcData.func = func;


        functions[funcData.name] = funcData;
    }

    /** 
     * Grabs all of the function 
     * definitions currently stored
     *
     * Returns: a `FunctionData[string]`
     * map
     */
    public FunctionData[string] grabFunctionDefs()
    {
        return this.functions.dup;
    }

    /** 
     * Grabs a function definition by its
     * name
     *
     * Params:
     *   name = the name of the function
     * Returns: the `FunctionData`
     * Throws:
     *   FuncDefStoreException if the function
     * could not be found
     */
    public FunctionData grabFunctionDef(string name)
    {
        if(name in this.functions)
        {
            return this.functions[name];
        }
        else
        {
            throw new FuncDefStoreException("Could not find function by name '"~name~"'");
        }
    }
}