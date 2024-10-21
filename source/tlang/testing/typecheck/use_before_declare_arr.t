module use_before_declare_arr;

int main()
{
	g[1] = g[0];
	int[2] g;
	
	return 0;
}