module complex_stack_array_coerce_bad2;

int val1;
int val2;

void coerce_bad2(int*** in) {}

int function()
{
    int[][2] stackArr;
    stackArr[0] = &val1;
    stackArr[1] = &val2;
    
    coerce_bad2(stackArr);

    return val1+val2;
}
