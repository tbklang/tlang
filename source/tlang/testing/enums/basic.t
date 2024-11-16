module basic;

enum Numberless : size_t
{
	ONE,
	TWO
}

int answer()
{
	return Numberless.ONE+Numberless.TWO;
}

int main()
{
	return answer();
}
