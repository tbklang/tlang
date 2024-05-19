module simple_binops_ptr_bad;

int main()
{
	int* ptr1 = 0;
	int* ptr2 = 0;

	int* ptr3 = ptr1+ptr2;

	return 0;
}
