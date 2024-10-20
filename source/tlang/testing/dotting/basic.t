module basic;

void g(int d)
{

}

void k()
{
	
}

int* getptr()
{
	return 0;
}

int sixnine()
{
	return 69;
}

int y()
{
	return sixnine()+1;
}

int global;

int main()
{
	int[2][2] stackArr;

	int[2] stack;

	int i = 1;
	i=1;

	int* arr;
	int[] d;

	
	*arr = 50;

	*arr = 51;

	*arr = basic.y()+1;

	*(d+1) = 2;

	d[69] = 7;
	
	stack[basic.y()] = basic.y();

	stack[y()] = y();

	arr[y()] = y();

	*(arr+1+y()) = 1+y();

	*(cast(int*)y()) = y();

	getptr()[0] = 1;

	g(1);

	return 0;
}
