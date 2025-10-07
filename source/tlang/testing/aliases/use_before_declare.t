module use_before_declare;

int c = 0;
int cnt()
{
	c=c+1;
	return c;
}

int identity(int i)
{
	return i;
}

int main()
{
	int o = identity(inner);
	alias inner = sizeof(uint)-cast(ubyte)1;
	return o;
}
