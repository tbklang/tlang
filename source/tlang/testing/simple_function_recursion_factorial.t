module simple_function_recursion_factorial;

ubyte factorial(ubyte i)
{
    if(i == cast(ubyte)0)
    {
        return 1;
    }
    else
    {
        return i*factorial(i-cast(ubyte)1);
    }
}