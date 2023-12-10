/** 
 * Provides the definition of a function definition
 * store and retrieval system
 */
module tlang.compiler.typecheck.dependency.store.interfaces;

import tlang.compiler.symbols.data : Function;
import tlang.compiler.typecheck.dependency.core : FunctionData;
import misc.exceptions : TError;

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
     * Throws:
     *   FuncDefStoreException if the function
     * has already been added
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

/**
 * Exception thrown when an error occurs
 * with the `IFuncDefStore` system
 */
public final class FuncDefStoreException : TError
{
    /** 
     * Constructs a new `FuncDefStoreException`
     * with the given error message
     *
     * Params:
     *   msg = the error message
     */
    this(string msg)
    {
        super(msg);
    }
}