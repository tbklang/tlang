module typeChecking1;

A aInstance = 1;
B bInstance = new B();
A.C cInstance;

int jNumber = A.jStatic;

class A
{
    static B bInstanceStatic;
    static int jStatic;
    static A aInstanceStatic;

    static class C
    {
        static int pStatic;
        static A.C ll;
    }
    
    B bInstance;
    int jInstance;
}

class B
{
    static A ds;
    static int kStatic;
    
}

