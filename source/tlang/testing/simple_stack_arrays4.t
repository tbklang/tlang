module simple_stack_arrays4;

int function()
{
    int[22222] myArray;

    int i = 2;
    myArray[i] = 60;
    myArray[2] = myArray[i]+1;

    return myArray[2];
}