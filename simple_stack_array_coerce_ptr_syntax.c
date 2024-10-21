/**
 * TLP compiler generated code
 *
 * Module name: simple_stack_array_coerce_ptr_syntax
 * Output C file: simple_stack_array_coerce_ptr_syntax.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


void coerce(int32_t* t_58b28bc1420b1bc0d1132a258153df6b);

int32_t function();

void coerce(int32_t* t_58b28bc1420b1bc0d1132a258153df6b)
{
	// Not emitting for parameter 'Variable (Ident: in, Type: int*)'
	*(t_58b28bc1420b1bc0d1132a258153df6b+0) = 69;
	*(t_58b28bc1420b1bc0d1132a258153df6b+1) = 420;
}

int32_t function()
{
	int32_t t_823be6da3dede3cdb1c2cde6e87678c1[2];
	coerce(t_823be6da3dede3cdb1c2cde6e87678c1);
	return t_823be6da3dede3cdb1c2cde6e87678c1[0]+t_823be6da3dede3cdb1c2cde6e87678c1[1];
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
