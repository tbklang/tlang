module simple_usage;

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
	alias inner = sizeof(uint)-cast(ubyte)1;
	int o = identity(inner);
	return o;
}