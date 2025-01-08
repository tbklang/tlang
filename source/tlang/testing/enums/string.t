module string;

extern efunc void printf(ubyte* s);

enum Message
{
	START = "An apple\n",
	END
}

int main()
{
	printf(Message.START);
	return Message.START[0];
}
