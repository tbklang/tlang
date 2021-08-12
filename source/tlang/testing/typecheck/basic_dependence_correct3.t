module typeChecking2;

A aInstance;
B bInstance;

int j = k;
int k = j;

 
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
    static int j=k;
    static int k;
    int p;
}
