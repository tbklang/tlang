module usage_capture;

alias doIt = doubler(i);

int doubler(int i)
{
    return i*2;
}

int main()
{
    int i = 2;

    return doIt;
}