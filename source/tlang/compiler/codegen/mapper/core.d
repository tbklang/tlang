/** 
 * Provides symbol mapping
 * interfaces for the emitting
 * stage
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.codegen.mapper.core;

import tlang.compiler.symbols.data : Entity;

/** 
 * The symbol mapping interface
 * that any symbol mapper must
 * implement in order to be used
 * in the `DGen` code emitter
 */
public interface SymbolMapper
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

/** 
 * Describes the mapping technique to use
 *
 * This describes which engine should be
 * used to map entities to emittable
 * names
 */
public enum SymbolMappingTechnique : string
{
    /**
     * Uses a hash-based approach to
     * generating names
     */
    HASHMAPPER = "hashmapper",

    /**
     * Uses a more human-readable
     * approach to generating
     * names
     */
    LEBANESE = "lebanese"
}