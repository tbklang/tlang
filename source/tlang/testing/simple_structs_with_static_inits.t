module simple_structs_with_static_inits;

class Cart
{
    static int items;
    static int balance;
}

struct User
{
    Cart cart;
    byte* name;
    int age;
}

User u1;
User u2;