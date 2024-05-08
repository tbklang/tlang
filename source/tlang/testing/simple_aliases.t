module simple_aliases;

int c = 0;
int cnt()
{
	c=c+1;
	return c;
}

alias expr = cnt();

alias inner = 1;

int main()
{
	alias inner = 0;
	int i = expr;
	int p = expr;
	int o = inner;
	return i+p+o;
}
