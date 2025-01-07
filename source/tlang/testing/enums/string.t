module string;

enum Message
{
	START = "A",
	END
}

int main()
{
	return Message.START[0];
}
