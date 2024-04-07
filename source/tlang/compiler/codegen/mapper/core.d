module tlang.compiler.codegen.mapper.core;

import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import std.conv : to;
import gogga;


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