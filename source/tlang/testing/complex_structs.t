module complex_structs;

struct Cart
{
    int count;
}

struct User
{
    int age;
    Cart cart;
}

User u1;

void function()
{
    int userAge = u1.age;
    Cart* userCart = &u1.cart;
    int userCartCount = u1.cart.count;
}