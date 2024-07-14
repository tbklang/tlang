module simple_aliases;

int c = 0;
int cnt()
{
	c=c+1;
	return c;
}

alias expr = cnt();

alias inner = 1;

int identity(int i)
{
	return i;
}

int main()
{
	alias inner = sizeof(ubyte)-cast(ubyte)1;
	int i = expr;
	int p = expr;
	int o = identity(inner);
	return i+p+o;
}
