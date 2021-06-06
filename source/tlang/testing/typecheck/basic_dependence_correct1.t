module typeChecking1;

A aInstance;

class A
{
    static A aInstance;
    static typeChecking1.B bInstance;
    static C cInstance;

    class C
    {
        static B bInstance;
    }
}

class B
{
    static A.C cInstance;
    static B bInstance;
}