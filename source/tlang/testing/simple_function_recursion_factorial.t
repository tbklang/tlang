module simple_function_recursion_factorial;

ubyte factorial(ubyte i)
{
    if(i == 0)
    {
        return 1;
    }
    else
    {
        return i*factorial(i-1);
    }
}