library:
	gcc library.c -shared -o library.o

clean:
	rm library.o
	rm main

main:
	gcc main.c library.o -o main
