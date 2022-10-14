module simple_class_ref;

class A
{
    static int aVal = 55;
}

class TestClass
{
    static int x = 2;
    static A y;

    static class P
    {
        static int h;
    }
}

int testValue = TestClass.P.h;