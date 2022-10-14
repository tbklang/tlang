module simple_class_ref;

class A
{
    static int aVal = 55;
}

class TestClass
{
    static int x = 2;
    static A y = 3;
}

int testValue = TestClass.x;