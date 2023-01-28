#include<unistd.h>

int ctr = 2;

unsigned int doWrite(unsigned int fd, unsigned char* buffer, unsigned int count)
{
    write(fd, buffer, count+ctr);
}