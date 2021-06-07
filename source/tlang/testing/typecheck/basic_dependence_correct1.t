module typeChecking1;

B bInstance;
A aInstance = 1;
A.C cInstance;

int jNumber;

class A
{
    static B bInstanceStatic;
    static int jStatic;
    static A aInstanceStatic;

    static class C
    {
        static int jStatic;
    }
    
    B bInstance;
    int jInstance;
}

class B
{
    static int kStatic;
    
}

