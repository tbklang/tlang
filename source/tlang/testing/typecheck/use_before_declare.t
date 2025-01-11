module use_before_declare;

int main()
{
	g = g + 2;
	int g;
	return 0;
}