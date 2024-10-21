module simple_function_call;

int j = 1+func(3,test()+t2()+t2());
int k = 2+func(j,test());

int func(int x1, byte x2)
{
    return 1;
}

byte t2()
{
    return 1;
}

byte test()
{
    return 1;
}
