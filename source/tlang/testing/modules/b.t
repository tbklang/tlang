module b;

import a;

public int doThing()
{
    int local = 0;

    for(int i = 0; i < 10; i=i+1)
    {
        local = local + a.ident(i);
    }

    return local;
}

// You should NOT be able to see me
private int g;

private void nothing()
{

}