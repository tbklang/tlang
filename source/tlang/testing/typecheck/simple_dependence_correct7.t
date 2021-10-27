module typeChecking3;

class F
{

}

p = 4;

int p = 21;
int j = 2;
discard "SO far the bottom is done as (p+j)/1";
int k = p+j/1;

discard "getCOntainers, muyst reorder";
discard "And include stdalone assignments";
p = 4;