module complex_stack_array_coerce;

int val1;
int val2;

void coerce(int** in)
{
    in[0][0] = 69;
    in[1][0] = 420;
}

int function()
{
    int[][2] stackArr;
    stackArr[0] = &val1;
    stackArr[1] = &val2;
    
    discard coerce(stackArr);

    return val1+val2;
}