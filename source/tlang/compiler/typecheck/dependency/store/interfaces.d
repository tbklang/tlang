module tlang.compiler.typecheck.dependency.store.interfaces;

import tlang.compiler.symbols.data : Function;
import tlang.compiler.typecheck.dependency.core : FunctionData;

/** 
 * Represents a storage mechanism
 * which can store and retrieve
 * function definition datas
 */
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
    public FunctionData grabFunctionDef(string name);
}

import misc.exceptions : TError;

public final class FuncDefStoreException : TError
{
    this(string msg)
    {
        super(msg);
    }
}