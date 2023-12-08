module tlang.compiler.typecheck.dependency.store.impls;

import tlang.compiler.typecheck.dependency.store.interfaces : IFuncDefStore;
import tlang.compiler.symbols.data : Function;

import tlang.compiler.typecheck.dependency.core : FunctionData;

public final class FuncDefStore : IFuncDefStore
{
    /**
     * All declared functions
     */
    private FunctionData[string] functions;

    /** 
     * Adds the function definition
     * to the store
     *
     * Params:
     *   func = the function to add
     */
    public void addFunctionDef(Function func)
    {
        // TODO: Implement me
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
}