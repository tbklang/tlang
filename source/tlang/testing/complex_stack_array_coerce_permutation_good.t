module complex_stack_array_coerce_permutation_good;

int val1;
int val2;

void coerce_good1(int** in) {}
void coerce_good2(int[][] in) {}
void coerce_good3(int[]* in) {}
void coerce_good4(int*[] in) {}

int function()
{
    int[][2] stackArr;
    stackArr[0] = &val1;
    stackArr[1] = &val2;
    
    discard coerce_good1(stackArr);
    discard coerce_good2(stackArr);
    discard coerce_good3(stackArr);
    discard coerce_good4(stackArr);

    return val1+val2;
}