module simple_pointer_cast_le;

int j;

int ret()
{
    return 0;
}

int function(int* ptr)
{
    byte* bytePtr = cast(byte*)ptr;
    *bytePtr = 2+2;
    *(bytePtr+1) = 1;
    
    return (*ptr)+1*2;
}

int thing()
{
    int discardExpr = function(&j);
    int** l;

    return discardExpr;
}