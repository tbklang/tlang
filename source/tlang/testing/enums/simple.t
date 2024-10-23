module simple;

// Assigned value

enum Sex : uint
{
    Male,
	Female = 60,
	Unknown
}

// Assigned value

enum Gender
{
	Male,
	Female = 2147483648
}

// No assigned values

enum Numberless
{
	ONE,
	TWO
}

// TODO: ghet type chekcing working

// TODO: Make test case where reNum returns an int and coercion

// fails

long retEnum(Gender g)
{
	return g.Male;
}