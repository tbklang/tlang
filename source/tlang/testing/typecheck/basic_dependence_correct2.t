module typeChecking2;

A aInstance;
B bInstance;
int p = p+p*2;
int k =1+p+l;
int o = new A().l.p.p;
int o1 = new C().lplplp.p.p;

class A
{
    static int pStatic;
    static B bInstanceStatic;
    static A aInstanceStaticMoi;

    int poes;
}

class B
{
    static int jStatic;
    static A aInstanceStatic;
}

class C
{
    static int j = 1+1+k;
    static int k;
}
