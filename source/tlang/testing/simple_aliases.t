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
	int i = cnt();
	int p = cnt();
	return i+p;
}
