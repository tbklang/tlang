#!/bin/sh

# Compile C to object file as library to link in
gcc source/tlang/testing/file_io.c -c -o file_io.o

# Compile T to C, then compile C and link with other object file into a final object file
./tlang compile source/tlang/testing/simple_extern.t -sm HASHMAPPER -et true -pg true -ll file_io.o 

# Run the tlang file
./tlang.out

# Run (with strace) to see it
strace -e trace=write ./tlang.out
