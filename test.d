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
                    mov dword ptr [RSP], 69;
                    mov dword ptr CR3, 32;

                }
                
asm
                {
                    sub RSP, 4;
                    mov dword ptr [RSP], 69;
                    mov dword ptr CR3, 32;

                }
                
asm
                {
                    sub RSP, 4;
                    mov dword ptr [RSP], 69;
                    mov dword ptr CR3, 32;

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
