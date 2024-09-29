module b;

import a;

int doThing()
{
    int local = 0;

    for(int i = 0; i < 10; i=i+1)
    {
        b.doThing.local = local + a.ident(i);
    }

    return local;
}
