/**
 * TLP compiler generated code
 *
 * Module name: simple_pointer_cast_le
 * Output C file: simple_pointer_cast_le.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_e159019f766be1a175186a13f16bcfb7;

int32_t thing();

int32_t function(int32_t* t_7df91b856b018635c9d9262709fb03dd);

int32_t ret();

int32_t thing()
{
	int32_t t_24e95c7bfa46ce008604e2c107bddcf7 = function(&t_e159019f766be1a175186a13f16bcfb7);
	int32_t** t_865e4d65440be56a776d0aaba2a0bf9c;
	return t_24e95c7bfa46ce008604e2c107bddcf7;
}

int32_t function(int32_t* t_7df91b856b018635c9d9262709fb03dd)
{
	// Not emitting for parameter 'Variable (Ident: ptr, Type: int*)'
	int8_t* t_9297af97806701b31b2160ae2a54a0a2 = (int8_t*)t_7df91b856b018635c9d9262709fb03dd;
	*(t_9297af97806701b31b2160ae2a54a0a2) = 2+2;
	*(t_9297af97806701b31b2160ae2a54a0a2+1) = 1;
	return *t_7df91b856b018635c9d9262709fb03dd+1*2;
}

int32_t ret()
{
	return 0;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int retValue = thing();
    assert(t_e159019f766be1a175186a13f16bcfb7 == 256+4);
    assert(retValue == 256+4+2);

    return 0;
}
