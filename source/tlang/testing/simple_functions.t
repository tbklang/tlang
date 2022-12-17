module simple_functions;

int j = 21;
int k = 22;

int apple(int arg1, int arg2)
{
    int h = 69;

    arg1=1+arg1;

    k=arg1+arg2;
    simple_functions.k=arg1+arg2;
}

int banana(int arg1)
{
    int h = 64;

    k=1+h+apple(1, apple(2, 3))+k;
    
}