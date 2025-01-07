module string;

enum Message
{
	START = "A",
	END = "B"
}

int main()
{
	return Message.START[0];
}
