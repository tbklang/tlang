module simple_structs;

struct User
{
    byte* name;
    int age;
}

User u1;
User u2;

void function()
{
    int i = u1.age+1;

    u1.age = 1;
}