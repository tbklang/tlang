module simple_functor;

class TestClass
{
    static int value = 2;
}


int main()
{
    int j = 0;

    j = 2+TestClass.value;

    while(j < 10)
    {
        j = j + 1;
    }
}
