#include<stdlib.h>

int ctr = 2;

unsigned long* memAlloc(unsigned long sizeAlloc)
{
    return malloc(sizeAlloc);
}

void memFree(unsigned long* memory)
{
    free(memory);
}
