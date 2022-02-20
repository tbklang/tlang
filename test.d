module simple;
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
            mov R14B, 65;
        }
        

        asm
        {
            mov R13B, 65;
        }
        
