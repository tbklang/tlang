module typeChecking1;

A aInstance = 1;
B bInstance;
A.C cInstance;

int jNumber;

class A
{
    static B bInstanceStatic;
    static int jStatic;
    static A aInstanceStatic;

    static class C
    {
        static int pStatic;
    }
    
    B bInstance;
    int jInstance;
}

class B
{
    static int kStatic;
    static A ds;
}

