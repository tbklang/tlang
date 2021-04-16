module compiler.symbols.typing;

import compiler.symbols.data;

// public interface Type
// {
//     public 
// }

// public class PrimitiveType : Type
// {

// }

/* TODO: Make Container interface (for `getParent` and `getMembers`), then Clazz and PrimitiveType inherit Type, fuck lmao
/* TODO: Type then ofc Entity (for `name`) */

public class Type : Entity
{
    this(string name)
    {
        super(name);
    }
}