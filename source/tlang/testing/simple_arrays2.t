module simple_arrays2;

void function()
{
    int*[] myArray1;
    int[]* myArray2;

    myArray2 = cast(int[]*)myArray2;
    myArray2 = cast(int[][])myArray2;
    myArray2 = cast(int**)myArray2;
    myArray2 = cast(int*[])myArray2;
}