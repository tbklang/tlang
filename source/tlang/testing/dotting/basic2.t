module basic2;

void k(int i, int* p)
{
	p[0] = i;
}

int main()
{
	int[2] arr;
	basic2.k(257, arr);

	return arr[0];
}
