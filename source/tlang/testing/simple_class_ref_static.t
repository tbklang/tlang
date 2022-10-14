module simple_class_ref;

class A
{
    static int aVal;
}

class TestClass
{
    static int x = 2;
    static int A = 3;
}

int testValue = TestClass.x;