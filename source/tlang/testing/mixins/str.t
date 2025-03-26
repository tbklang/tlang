module str;

void main()
{
	mixin("int j=2"); mixin("int k");

	int f = mixin("1+1");
}
