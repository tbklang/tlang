module oopTest;

Person p1 = new Person();
Person p2;

p1();
discard 1+1;
discard p1;
discard p1();
discard new Person();

class Person
{
    private static int varStatic;
    private int varInstance;

    private void increment()
    {
        varInstance = varInstance+1;
    }

   
}