module simple_func_1;

int f(byte i, int k)
{
    return i+k;
}

int thing()
{
    int ans = simple_func_1.f(4,5);

    return ans;
}

int main()
{
    return thing();
}