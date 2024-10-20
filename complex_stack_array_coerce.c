/**
 * TLP compiler generated code
 *
 * Module name: complex_stack_array_coerce
 * Output C file: complex_stack_array_coerce.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_596f49b2a2784a3c1b073ccfe174caa0;
int32_t t_4233b83329676d70ab4afaa00b504564;

void coerce(int32_t** t_3c9f4dd4bcbd4f1acd7651ddb0e904d9);

int32_t function();

void coerce(int32_t** t_3c9f4dd4bcbd4f1acd7651ddb0e904d9)
{
	// Not emitting for parameter 'Variable (Ident: in, Type: int**)'
	*(*(t_3c9f4dd4bcbd4f1acd7651ddb0e904d9+0)+0) = 69;
	*(*(t_3c9f4dd4bcbd4f1acd7651ddb0e904d9+1)+0) = 420;
}

int32_t function()
{
	int32_t* t_2323ca35391209e7a7d08312c487cb09[2];
	t_2323ca35391209e7a7d08312c487cb09[0] = &t_596f49b2a2784a3c1b073ccfe174caa0;
	t_2323ca35391209e7a7d08312c487cb09[1] = &t_4233b83329676d70ab4afaa00b504564;
	coerce(t_2323ca35391209e7a7d08312c487cb09);
	return t_596f49b2a2784a3c1b073ccfe174caa0+t_4233b83329676d70ab4afaa00b504564;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 69+420);

    printf("val1: %d\n", t_596f49b2a2784a3c1b073ccfe174caa0);
    printf("val2: %d\n", t_4233b83329676d70ab4afaa00b504564);
    printf("stackArr sum: %d\n", result);

    return 0;
}
