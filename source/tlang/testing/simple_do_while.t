module simple_do_while;

int function(int i)
{
    // 4-1 -> 3
    // test = 0+3

    // 3-1 -> 2
    // test = 3+2

    // 2-1 -> 1
    // test = 3+2+1

    // 1> 1 -> false

    // return 3+2+1 -> 6

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
