/**
 * TLP compiler generated code
 *
 * Module name: simple_direct_func_call
 * Output C file: simple_direct_func_call.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_de44aff5a74865c97c4f8701d329f28d = 0;

void function();

void otherFunction(int32_t t_44314bca407fd2555bba7701b7d76ff1);

void function()
{
	otherFunction(69);
}

void otherFunction(int32_t t_44314bca407fd2555bba7701b7d76ff1)
{
	// Not emitting for parameter 'Variable (Ident: i, Type: int)'
	t_de44aff5a74865c97c4f8701d329f28d = t_44314bca407fd2555bba7701b7d76ff1;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    // Before it should be 0
    assert(t_de44aff5a74865c97c4f8701d329f28d == 0);

    // Call the function
    function();

    // After it it should be 69
    assert(t_de44aff5a74865c97c4f8701d329f28d == 69);
    
    return 0;
}
