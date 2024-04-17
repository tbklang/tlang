module simple_comments;

// Lol

int i;


int p;

/**
 * Other comment
 */

/**
 *    Takes two inputs, does nothing with
  them and then returns 0 nonetheless
 *
 * @param   x  This is the first input
 *@param y This is the second    input
 * @param niks   this  r e a l l y doesn't do anything
 * @throws ZeroException if the values passed in are not zero
 * @return Just the value 0
 */
int zero(int x, int y)
{
	return 0;
}



int main()
{
	int k = zero();
	*(cast(int*)0) = zero(0);
	return 0;
}
