/**
 * TLP compiler generated code
 *
 * Module name: simple_stack_arrays4
 * Output C file: simple_stack_arrays4.c
 *
 * Place any extra information by code
 * generator here
 */
#include<stdint.h>


int32_t function();

int32_t function()
{
	int32_t t_f158415769b0d390fbf30afbe143dffd[22222];
	int32_t t_59beaaabf0efe9fddbd7b90f9a14225a = 2;
	t_f158415769b0d390fbf30afbe143dffd[t_59beaaabf0efe9fddbd7b90f9a14225a] = 60;
	t_f158415769b0d390fbf30afbe143dffd[2] = t_f158415769b0d390fbf30afbe143dffd[t_59beaaabf0efe9fddbd7b90f9a14225a]+1;
	return t_f158415769b0d390fbf30afbe143dffd[2];
}


#include<stdio.h>
#include<assert.h>
int main()
{
    int result = function();
    assert(result == 61);

    return 0;
}
