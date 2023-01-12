module simple_pointer;

int j;

int function(int* ptr)
{
    *ptr = 2+2;

    return 0;
}

int thing()
{
    int discardExpr = function(&j);
    int** l;
}