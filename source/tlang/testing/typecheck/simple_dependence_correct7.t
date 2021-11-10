module typeChecking3;



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

class F
{
    static G f1;

    P p1;
    static P p2;

    static class P
    {

    }
}

class G
{
    static F g1;
}


F f;
G g;