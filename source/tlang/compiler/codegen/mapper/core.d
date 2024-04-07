module tlang.compiler.codegen.mapper.core;

import tlang.compiler.typecheck.core;
import tlang.compiler.symbols.data;
import std.conv : to;
import gogga;




public enum SymbolMappingTechnique : string
{
    HASHMAPPER = "hashmapper",
    LEBANESE = "lebanese"
}