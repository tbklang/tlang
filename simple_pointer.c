/**
 * TLP compiler generated code
 *
 * Module name: simple_pointer
 * Output C file: simple_pointer.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_87bc875d0b65f741b69fb100a0edebc7;

int32_t thing();

int32_t function(int32_t* t_749aad5a7510a19603a8e5de1a66fcb5);

int32_t thing()
{
	int32_t t_20d37ecbd4fd5d46c66d61a309a81727 = function(&t_87bc875d0b65f741b69fb100a0edebc7);
	int32_t** t_31bce1375a8d95ef83242371693caf84;
	return t_20d37ecbd4fd5d46c66d61a309a81727;
}

int32_t function(int32_t* t_749aad5a7510a19603a8e5de1a66fcb5)
{
	// Not emitting for parameter 'Variable (Ident: ptr, Type: int*)'
	*(t_749aad5a7510a19603a8e5de1a66fcb5+0) = 2+2;
	return *t_749aad5a7510a19603a8e5de1a66fcb5+1*2;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_87bc875d0b65f741b69fb100a0edebc7 == 4);
    assert(retValue == 6);

    return 0;
}
