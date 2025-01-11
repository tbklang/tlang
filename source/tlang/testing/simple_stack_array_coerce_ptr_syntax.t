module simple_stack_array_coerce_ptr_syntax;

void coerce(int* in)
{
    *(in+0) = 69;
    *(in+1) = 420;
}

int function()
{
    int[2] stackArr;
    coerce(stackArr);

    return stackArr[0]+stackArr[1];
}
