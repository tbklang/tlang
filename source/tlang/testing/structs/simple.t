module simple;

struct Person
{
	uint age;
	ubyte gender;
	IQ iq;
}

struct Race
{

}

struct IQ
{
	ubyte math;
	ubyte english;
	Race r;
}

IQ k;
IQ* kPtr;

IQ makeIQ()
{
	IQ d;
	return d;
}

void usage2(Person p)
{

}

void usage(Person p)
{
	p.iq.math = 1+p.gender;
	p.iq.math = p.age+1;

	p.iq = simple.k;
	p.iq = k;

	kPtr = &k;

	int i = makeIQ().math;

	usage2(p);
	p = p;
	IQ o;
	o = makeIQ();
	o = simple.makeIQ();
}