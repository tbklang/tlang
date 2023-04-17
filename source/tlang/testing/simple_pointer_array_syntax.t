module simple_pointer_array_syntax;

int j;

int function(int[] ptr)
{
    *(ptr+0) = 2+2;
    return (*ptr)+1*2;
}

int thing()
{
    int discardExpr = function(&j);
    int** l;

    return discardExpr;
}