module class_deps_simple;

class TestClass
{
    static int value = 2;
}

class TestClass2
{
    static int k = TestClass.value;
}

TestClass d;