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

int main()
{
	IQ i;
	IQ p;

	i.math = 1;
	i.english = 2;

	p = i;

	uint _s1 = p.math == i.math;
	uint _s2 = p.english == i.english;
	ubyte status = cast(ubyte)(_s1 == _s2);

	IQ* iPtr = &i;
	*iPtr.i = 1;

	return status;
}