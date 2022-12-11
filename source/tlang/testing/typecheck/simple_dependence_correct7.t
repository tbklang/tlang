module typeChecking3;


discard "rsolution.d(126) seems to fail below (REMOVE THIS WHEN FIXED)";
int t;
int p = 21;
p=2+p;
int j = 2;
discard "SO far the bottom is done as (p+j)/1";
int k = p+j/1;

discard "getCOntainers, muyst reorder";
discard "And include stdalone assignments";
p = 4;

p = 4;
p = 4;
p = 4;
p = 4;
j=232321213;

discard "Must look at case the above line doesn't exist and STILL we should allocate (line 28)";

class F
{
    static G f1;

    P p1;
    static P p2;

    

    static class P
    {
        int p1;
        static int p2;
    }
}

class G
{
    static F g1;
    static int g2Number;

    static class P
    {
        static F.P otherP1;
        static G.P thisp1;
    }
}


F f;
G g;
