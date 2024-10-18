module simple_illmember;

struct Person
{
	ubyte x;
}

void usage(Person p)
{
	p.y = 1;
}