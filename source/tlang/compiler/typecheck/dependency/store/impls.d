/** 
 * Provides implementation of the `IFuncDefStore`
 * interface
 */
module tlang.compiler.typecheck.dependency.store.impls;

import tlang.compiler.typecheck.dependency.store.interfaces;
import tlang.compiler.symbols.data : Function, Module;
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
     *   owner = the `Module` wherein
     * this function is declared
     *   func = the function to add
     * Throws:
     *   FuncDefStoreException if the function
     * has already been added
     */
    public void addFunctionDef(Module owner, Function func)
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
        funcData.setOwner(owner);

        functions[funcData.name] = funcData;
    }

    /** 
     * Grabs all of the function 
     * definitions currently stored
     * in relation to those declared
     * in the given module
     *
     * Params:
     *  owner = the `Module` to
     * search
     *
     * Returns: a `FunctionData[string]`
     * map
     */
    public FunctionData[string] grabFunctionDefs(Module owner)
    {
        // Find all functions which have an owner matching
        // the provided one and construct a new map from
        // that
        FunctionData[string] ofOwner;
        foreach(FunctionData fd; this.functions)
        {
            if(fd.getOwner() is owner)
            {
                ofOwner[fd.getName()] = fd;
            }
        }

        return ofOwner;
    }

    /** 
     * Grabs a function definition by its
     * name
     *
     * Params:
     *   owner = the `Module` wherein the
     * function is declared
     *   name = the name of the function
     * Returns: the `FunctionData`
     * Throws:
     *   FuncDefStoreException if the function
     * could not be found
     */
    public FunctionData grabFunctionDef(Module owner, string name)
    {
        FunctionData* potential = name in this.functions;
        if(potential)
        {
            if(potential.getOwner() is owner)
            {
                return *potential;
            }
            else
            {
                throw new FuncDefStoreException("We found a function with name '"~name~"' HOWEVER not in owner '"~owner.getName()~"'");
            }
        }
        else
        {
            throw new FuncDefStoreException("Could not find function by name '"~name~"'");
        }
    }
}