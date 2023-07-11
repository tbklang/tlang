module meta_sizeof;

size_t myVar1 = sizeof(uint);
size_t myVar2 = sizeof(ubyte);
size_t myVar3 = sizeof(ushort)+1;

myVar3 = sizeof(ulong)+sizeof(size_t);
