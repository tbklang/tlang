module simple_extern;

extern efunc uint write(uint fd, ubyte* buffer, uint count);
extern evar int kak;

void test()
{
    ubyte* buff;
    discard write(cast(uint)0, buff, cast(uint)1001);

    kak = kak + 1;
}