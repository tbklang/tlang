/**
 * TLP compiler generated code
 *
 * Module name: simple_stack_array_coerce
 * Output C file: simple_stack_array_coerce.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


void coerce(int32_t* t_b67a82c7e4972a156d6cb6f40d66b4b2);

int32_t function();

void coerce(int32_t* t_b67a82c7e4972a156d6cb6f40d66b4b2)
{
	// Not emitting for parameter 'Variable (Ident: in, Type: int*)'
	*(t_b67a82c7e4972a156d6cb6f40d66b4b2+0) = 69;
	*(t_b67a82c7e4972a156d6cb6f40d66b4b2+1) = 420;
}

int32_t function()
{
	int32_t t_bd85ba63bc20b81b32086fef35195c3f[2];
	coerce(t_bd85ba63bc20b81b32086fef35195c3f);
	return t_bd85ba63bc20b81b32086fef35195c3f[0]+t_bd85ba63bc20b81b32086fef35195c3f[1];
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 420+69);
    printf("stackArr sum: %d\n", result);

    return 0;
}
