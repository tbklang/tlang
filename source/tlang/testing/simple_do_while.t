module simple_do_while;

int function(int i)
{
    int test = 2;
    do
    {
        i = i - 1;
        test = test + i;
    }
    while(i);

    return test;
}