library:
	gcc -c library.c -o library.o

clean:
	rm library.o
	rm main.o
	rm main

main:
	gcc -c main.c library.o -o main.o

exec:
	gcc main.o library.o -o main
