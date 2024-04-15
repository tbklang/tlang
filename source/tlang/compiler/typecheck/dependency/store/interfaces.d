/** 
 * Provides the definition of a function definition
 * store and retrieval system
 */
module tlang.compiler.typecheck.dependency.store.interfaces;

import tlang.compiler.symbols.data : Function, Module;
import tlang.compiler.typecheck.dependency.core : FunctionData;
import tlang.misc.exceptions : TError;

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
     *   owner = the `Module` wherein
     * this function is declared
     *   func = the function to add
     * Throws:
     *   FuncDefStoreException if the function
     * has already been added
     */
    public void addFunctionDef(Module owner, Function func);

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
    public FunctionData[string] grabFunctionDefs(Module owner);

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
    public FunctionData grabFunctionDef(Module owner, string name);
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