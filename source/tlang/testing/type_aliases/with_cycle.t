module with_cycle;

type basicIntegerType = returnType;
type returnType = basicIntegerType;

returnType main()
{
  return 0;
}