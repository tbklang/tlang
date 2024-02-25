module tlang.compiler.codegen.mapper.api;

import tlang.compiler.symbols.data : Entity;

/** 
 * The symbol mapping interface
 * that any symbol mapper must
 * implement in order to be used
 * in the `DGen` code emitter
 */
public interface SymbolMapperV2
{
    /** 
     * Maps the given `Entity` to a symbol
     * name with the provided scope type
     *
     * Params:
     *   item = the entity to generate a
     * symbol name for
     *   type = the `ScopeType` to map
     * using
     * Returns: the symbol name
     */
    public string map(Entity item, ScopeType type);
}

/** 
 * Specifies the kind-of mapping
 * that should be done regarding
 * the scope/visibility of the
 * generated symbol name during
 * link time
 */
public enum ScopeType
{
    /** 
     * The mapped symbol name
     * should be globally accessible
     */
    GLOBAL,

    /** 
     * The mapped symbol name
     * should only be valid
     * within the current scope
     * it was requested from
     */
    LOCAL
}