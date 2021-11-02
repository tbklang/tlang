module typeChecking3;
void main()
{

        asm
        {
            mov R15, RSP;
        }
        
asm
                    {
                        sub RSP, 4;
                    }
                    
asm
                    {
                        sub RSP, 4;
                    }
                    
asm
                    {
                        sub RSP, 4;
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
