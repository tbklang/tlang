module tlang.compiler.typecheck.dependency.store.interfaces;

import tlang.compiler.symbols.data : Function;
import tlang.compiler.typecheck.dependency.core : FunctionData;

public interface IFuncDefStore
{
    /** 
     * Adds the function definition
     * to the store
     *
     * Params:
     *   func = the function to add
     */
    public void addFunctionDef(Function func);

    /** 
     * Grabs all of the function 
     * definitions currently stored
     *
     * Returns: a `FunctionData[string]`
     * map
     */
    public FunctionData[string] grabFunctionDefs();
}