/**
 * TLP compiler generated code
 *
 * Module name: simple_for_loops
 * Output C file: simple_for_loops.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


int32_t function(int32_t t_aaf2abfaa7ee1293cb9371660802cd54);

int32_t function(int32_t t_aaf2abfaa7ee1293cb9371660802cd54)
{
	// Not emitting for parameter 'Variable (Ident: i, Type: int)'
	int32_t t_9ed0c4a44bed8165b36a4f22392c6bb7 = 0;
	for(int32_t t_0418063afb30b380d8096b28943a91ea = 0;t_0418063afb30b380d8096b28943a91ea<t_aaf2abfaa7ee1293cb9371660802cd54;)
	{
		t_9ed0c4a44bed8165b36a4f22392c6bb7 = t_9ed0c4a44bed8165b36a4f22392c6bb7+1;
		t_0418063afb30b380d8096b28943a91ea = t_0418063afb30b380d8096b28943a91ea+1;
	}
	return t_9ed0c4a44bed8165b36a4f22392c6bb7;
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
