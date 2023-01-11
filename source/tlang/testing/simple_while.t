module simple_while;

int function(int i)
{
    int test = 0;

    while(i)
    {
        int p = 1;
        int f = 2;
        f = p+f;

        i = i - 1;
        test = i + test;
    }

    int j = 2;

    return test;
}