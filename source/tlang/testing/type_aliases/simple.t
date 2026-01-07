module simple;

type basicIntegerType = ubyte;
type returnType = basicIntegerType;

int main()
{
  return sizeof(returnType)*cast(uint)2;
}