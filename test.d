module simple_class_ref;
void main()
{

        asm
        {
            mov R15, RSP;
        }
        

        asm
        {
            mov RSP, R15;
        }
        

        int h = -1;
        h = *((&h)-4);
        import std.stdio;
        writeln(h);
        
}
