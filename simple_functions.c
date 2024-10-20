/**
 * TLP compiler generated code
 *
 * Module name: simple_functions
 * Output C file: simple_functions.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>

int32_t t_ac827ade536536931b60933c9adb98cc = 21;
int32_t t_7b6d477c5859059f16bc9da72fc8cc3b = 22;

int32_t apple(int32_t t_c586afa699fad7b9ba0ceb2d4475e79a, int32_t t_5549f271ea60289ff27aa353144cb6fd);

int32_t banana(int32_t t_dfb9f9d287f84736e7c04608e8443a70);

int32_t apple(int32_t t_c586afa699fad7b9ba0ceb2d4475e79a, int32_t t_5549f271ea60289ff27aa353144cb6fd)
{
	// Not emitting for parameter 'Variable (Ident: arg1, Type: int)'
	// Not emitting for parameter 'Variable (Ident: arg2, Type: int)'
	int32_t t_9ec2f7d2c0db760d95aa841d38c87a5b = 69;
	t_c586afa699fad7b9ba0ceb2d4475e79a = 1+t_c586afa699fad7b9ba0ceb2d4475e79a;
	t_7b6d477c5859059f16bc9da72fc8cc3b = t_c586afa699fad7b9ba0ceb2d4475e79a+t_5549f271ea60289ff27aa353144cb6fd;
	t_7b6d477c5859059f16bc9da72fc8cc3b = t_c586afa699fad7b9ba0ceb2d4475e79a+t_5549f271ea60289ff27aa353144cb6fd;
	return t_c586afa699fad7b9ba0ceb2d4475e79a;
}

int32_t banana(int32_t t_dfb9f9d287f84736e7c04608e8443a70)
{
	// Not emitting for parameter 'Variable (Ident: arg1, Type: int)'
	int32_t t_280ac0fbb9196fef914d76c791b222ff = 64;
	t_7b6d477c5859059f16bc9da72fc8cc3b = 1+t_280ac0fbb9196fef914d76c791b222ff+apple(1, apple(2, 3))+t_7b6d477c5859059f16bc9da72fc8cc3b;
	return 0;
}


#include<stdio.h>
#include<assert.h>
int main()
{
    assert(t_7b6d477c5859059f16bc9da72fc8cc3b == 22);
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);
    
    banana(1);
    assert(t_7b6d477c5859059f16bc9da72fc8cc3b == 72);
    printf("k: %u\n", t_7b6d477c5859059f16bc9da72fc8cc3b);

    return 0;
}
