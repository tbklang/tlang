module simple_function_decls;

int j = 21;
int k = 22;

int apple(int arg1, int arg2)
{
    int h = 69;

    arg1=1+arg1;

    k=1;
}

int banana(int arg1)
{
    int h = 64;

    k=1+h+apple(1, apple(2, 3));
    
}