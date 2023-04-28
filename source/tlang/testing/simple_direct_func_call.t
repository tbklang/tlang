module simple_direct_func_call;

int myVar = 0;

void otherFunction(int i)
{
    myVar = i;
}

void function()
{
    otherFunction(69);
}