module simple_pointer_cast;

int j;

int ret()
{
    return 0;
}

int function(int* ptr)
{
    *(cast(int*)ret())=2;
    return (*ptr)+1*2;
}

int thing()
{
    int discardExpr = function(&j);
    int** l;

    return discardExpr;
}