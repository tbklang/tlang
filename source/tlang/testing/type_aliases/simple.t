module simple;

type basicIntegerType = uint;
type returnType = basicIntegerType;

returnType main()
{
  return sizeof(returnType)+cast(uint)1;
}