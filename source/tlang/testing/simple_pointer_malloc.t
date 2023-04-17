module simple_pointer_malloc;

extern efunc ubyte* memAlloc(ulong size);
extern efunc void memFree(ubyte* ptr);

void test()
{
    ubyte* memory = memAlloc(10UL);

    for(int i = 0; i < 10; i = i + 1)
    {
        *(memory+i) = 65+i;
    }

    discard memFree(memory);
}