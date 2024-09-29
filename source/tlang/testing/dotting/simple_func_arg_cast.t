module simple_func_arg_cast;

int thing(int i, int y)
{
	return i+y;
}

int main()
{
	ubyte one = 255;
	ubyte two = 255;
	return thing(one, two);
}
