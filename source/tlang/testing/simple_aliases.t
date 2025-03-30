module simple_aliases;

int c = 0;
int cnt()
{
	c=c+1;
	return c;
}

alias expr = cnt();

int main()
{
	int i = expr;
	int p = 1;
	return i+p;
}
