module file;

void main()
{
	embed("source/tlang/testing/mixins/decl.txt");

	int myVarName;
	myVarName = embed("source/tlang/testing/mixins/decl2.txt")+1;
}
