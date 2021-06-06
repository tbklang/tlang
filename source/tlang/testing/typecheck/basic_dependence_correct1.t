module typeChecking1;

class A
{
    static A aInstance;
    static typeChecking1.B bInstance;
    static C cInstance;

    static class C
    {
        static B bInstance;
    }
}

class B
{
    static B bInstance;
}