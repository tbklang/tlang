#!/bin/sh

# Compile C to object file as library to link in
gcc source/tlang/testing/mem.c -c -o mem.o

# Compile T to C, then compile C and link with other object file into a final object file
./tlang compile source/tlang/testing/simple_pointer_malloc.t -sm HASHMAPPER -et true -pg true -ll mem.o 

# Run the tlang file
./tlang.out

# Run (with strace) to see it
strace -e brk ./tlang.out
