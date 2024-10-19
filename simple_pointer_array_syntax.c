/**
 * TLP compiler generated code
 *
 * Module name: simple_pointer_array_syntax
 * Output C file: simple_pointer_array_syntax.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_9d01d71b858651e520c9b503122a1b7a;

int32_t thing();

int32_t function(int32_t* t_0c12369a4b0901db8ba79620e683f387);

int32_t thing()
{
	int32_t t_0ea71284a4f0f9d9d914971f98e403ef = function(&t_9d01d71b858651e520c9b503122a1b7a);
	int32_t** t_941008977e8fd45ceda5dc1f17b605ea;
	return t_0ea71284a4f0f9d9d914971f98e403ef;
}

int32_t function(int32_t* t_0c12369a4b0901db8ba79620e683f387)
{
	// Not emitting for parameter 'Variable (Ident: ptr, Type: int[])'
	*(t_0c12369a4b0901db8ba79620e683f387+0) = 2+2;
	return *t_0c12369a4b0901db8ba79620e683f387+1*2;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_9d01d71b858651e520c9b503122a1b7a == 4);
    assert(retValue == 6);

    return 0;
}
