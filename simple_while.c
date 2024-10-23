/**
 * TLP compiler generated code
 *
 * Module name: simple_while
 * Output C file: simple_while.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


int32_t function(int32_t t_77ce8b29b91f133c546b0d483e299971);

int32_t function(int32_t t_77ce8b29b91f133c546b0d483e299971)
{
	// Not emitting for parameter 'Variable (Ident: i, Type: int)'
	int32_t t_77307b049403ac7dc4a5d26859bd8f5a = 0;
	while(t_77ce8b29b91f133c546b0d483e299971)
	{
		int32_t t_8e6441ed928ebe9dfd0cce98d830468b = 1;
		int32_t t_aa18e9a0bbf60233e05e0b1584c42b72 = 2;
		t_aa18e9a0bbf60233e05e0b1584c42b72 = t_8e6441ed928ebe9dfd0cce98d830468b+t_aa18e9a0bbf60233e05e0b1584c42b72;
		t_77ce8b29b91f133c546b0d483e299971 = t_77ce8b29b91f133c546b0d483e299971-1;
		t_77307b049403ac7dc4a5d26859bd8f5a = t_77ce8b29b91f133c546b0d483e299971+t_77307b049403ac7dc4a5d26859bd8f5a;
	}
	int32_t t_0fbbc3eec6d9d12888768b030f97ccbd = 2;
	return t_77307b049403ac7dc4a5d26859bd8f5a;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function(3);
    printf("result: %d\n", result);
    assert(result == 3);

    return 0;
}
