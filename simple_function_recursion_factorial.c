/**
 * TLP compiler generated code
 *
 * Module name: simple_function_recursion_factorial
 * Output C file: simple_function_recursion_factorial.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


uint8_t factorial(uint8_t t_deea86e1d179f1ce7e7cf79f11460846);

uint8_t factorial(uint8_t t_deea86e1d179f1ce7e7cf79f11460846)
{
	// Not emitting for parameter 'Variable (Ident: i, Type: ubyte)'
	if(t_deea86e1d179f1ce7e7cf79f11460846==(uint8_t)0)
	{
		return (uint8_t)1;
	}
	else
	{
		return t_deea86e1d179f1ce7e7cf79f11460846*factorial(t_deea86e1d179f1ce7e7cf79f11460846-(uint8_t)1);
	}

}


#include<stdio.h>
#include<assert.h>
int main()
{
    int result = factorial(3);
    assert(result == 6);
    printf("factorial: %u\n", result);
    
    return 0;
}
