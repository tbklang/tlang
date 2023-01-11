module simple_for_loops;

int function(int i)
{
    int test = 0;

    for(int idx = 0; idx < i; idx=idx+1)
    {
        test = test + 1;
    }

    return test;
}