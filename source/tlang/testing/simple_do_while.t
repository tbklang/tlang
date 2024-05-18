module simple_do_while;

int function(int i)
{
    int test = 0;
    do
    {
        i = i - 1;
        test = test + i;
    }
    while(i > 1);

    return test;
}

int main()
{
	return function(4);
}
