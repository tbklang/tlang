module simple_usage;

int identity(int i)
{
	return i;
}

int main()
{
	alias inner = sizeof(uint)-cast(ubyte)1;
	int o = identity(inner+inner-inner);
	return o;
}