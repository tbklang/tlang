module simple_literals2;

ubyte var = 1;

int func()
{
    return 2;
}

void test()
{
    var = 2;
    var = func();
}