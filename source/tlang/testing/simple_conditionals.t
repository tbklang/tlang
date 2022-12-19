module simple_conditions;

int other(int arg1, int arg2)
{
    return 50;
}

void function(int i)
{
    int apple = 69;

    if(i == 1)
    {
        apple = 2;
        i = i +3;
        
        if(i == 40)
        {

        }
        else if(i == 41)
        {

        }
        else
        {

        }
    }
    else if(i == 2)
    {
        i = i +2;
    }
    else
    {
        
    }
    
    int banana = 24;
    banana=2+i;

    if(banana == 2+2+other(2,2))
    {
        banana=2;
        banana=3;
        banana = other(2,3)+other(3,4);
    }

    int pp = other(80,81);
}