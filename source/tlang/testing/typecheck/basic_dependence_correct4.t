module typeChecking2;

A aInstance;
B bInstance;

int j = 1;
int k = j+1;
int p = k+j;

C cInstance;

class A
{
    static int pStatic;
    static B bInstanceStatic;
    static A aInstanceStaticMoi;

    int poes;
}

class B
{
    static int jStatic;
    static A aInstanceStatic;
}

class C
{
    static int j=1;
    static int k = j;
    int p;
}
