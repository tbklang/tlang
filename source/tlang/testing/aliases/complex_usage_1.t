module complex_usage_1;

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
	alias inner_f = sizeof(uint)-cast(ubyte)1;
	alias inner2 = inner_f;
	int i = expr;
	int p = expr;
	int o = identity(inner+inner2);
	return i+p+expr+o;
}
