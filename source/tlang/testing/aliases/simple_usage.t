module simple_usage;

int identity(int i)
{
	return i;
}

int main()
{
	alias oneDef = 1;
	alias two = oneDef+oneDef;
	int o = identity(two+oneDef);
	return o;
}