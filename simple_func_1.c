/**
 * TLP compiler generated code
 *
 * Module name: simple_func_1
 * Output C file: simple_func_1.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


int32_t main();

int32_t thing();

int32_t f(int8_t t_80feb3a41721187a66866d7cddb0c2a1, int32_t t_d9af7d946f20c8700dc50e37fcbfe7d6);

int32_t main()
{
	return thing();
}

int32_t thing()
{
	int32_t t_3c5bc0f95439ed4a64c74527e3315f3c = f((int8_t)4, 5);
	return t_3c5bc0f95439ed4a64c74527e3315f3c;
}

int32_t f(int8_t t_80feb3a41721187a66866d7cddb0c2a1, int32_t t_d9af7d946f20c8700dc50e37fcbfe7d6)
{
	// Not emitting for parameter 'Variable (Ident: i, Type: byte)'
	// Not emitting for parameter 'Variable (Ident: k, Type: int)'
	return (int32_t)t_80feb3a41721187a66866d7cddb0c2a1+t_d9af7d946f20c8700dc50e37fcbfe7d6;
}

