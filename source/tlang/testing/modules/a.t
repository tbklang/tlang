module a;

import niks.c, b;

// Some public variable
public ubyte j = 0;

/**
 * This is the identity function,
 * it just returns what it was given
 *
 * @param i the input
 */
int ident(int i)
{
	c.k();
	return i;
}

/**
 * Entrypoint
 */
int main()
{
	int value = b.doThing();
	return value;
}
