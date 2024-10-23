module simple_extern;

extern efunc uint doWrite(uint fd, ubyte* buffer, uint count);
extern evar int ctr;

void test()
{
    ctr = ctr + 1;

    ubyte* buff;
    doWrite(cast(uint)0, buff, cast(uint)1001);
}