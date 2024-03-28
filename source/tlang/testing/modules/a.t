module a;

import niks.c;
import b;

int ident(int i)
{
	c.k();
	return i;
}

int main()
{
	int value = b.doThing();
	return value;
}
