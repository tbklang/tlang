module func_use_via_alias;

int call()
{
	return 1;
}

alias fCall = call();

int main()
{
	int i = fCall;
	i = fCall;
	return 0;
}