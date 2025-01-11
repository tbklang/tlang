module basic;

enum Numberless : size_t
{
	ONE,
	TWO
}

size_t answer()
{
	return Numberless.ONE+Numberless.TWO;
}

int main()
{
	return cast(int)answer();
}
