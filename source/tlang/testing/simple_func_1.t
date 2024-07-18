module simple_func_1;

int f(byte i, int k)
{
    return i+k;
}

void thing()
{
    int ans = simple_func_1.f(4,5);
}