module simple_extern;

extern efunc uint write(uint fd, ubyte* buffer, uint count);

void test()
{
    ubyte* buff;
    discard write(cast(uint)0, buff, cast(uint)1001);
}