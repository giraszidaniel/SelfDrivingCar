#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <string.h>
#include "uartfcntl.h"

int uartInit()
{
	const char *port_name = "/dev/ttyAMA0";
	int uart_fd = open(port_name, O_RDWR | O_NOCTTY | O_SYNC);
	if (uart_fd == -1)
	{
		perror("Hiba a port megnyitasakor");
		return 1;
	}
	struct termios options;
	memset(&options, 0, sizeof(options));
	if (tcgetattr(uart_fd, &options) != 0) 
	{
		perror("tcgetattr hiba");
		close(uart_fd);
		return 1;
	}
	cfmakeraw(&options);
	cfsetispeed(&options, B9600);
	cfsetospeed(&options, B9600);

	options.c_cflag &= ~PARENB;
	options.c_cflag &= ~CSTOPB;
	options.c_cflag &= ~CSIZE;
	options.c_cflag |= CS8;
	options.c_cflag |= CLOCAL;
	options.c_cflag |= CREAD;

#ifndef CRTSCTS
	options.c_cflag &= ~CRTSCTS;
#endif

	options.c_cc[VMIN] = 0;
	options.c_cc[VTIME] = 5;

	tcflush(uart_fd, TCIOFLUSH);
	if (tcsetattr(uart_fd, TCSANOW, &options) != 0)
	{
		perror("tcsetattr hiba");
		close(uart_fd);
		return 1;
	}
	write(STDOUT_FILENO,"Adatkuldes...",14);
	return uart_fd;
}

int uartTransmitter(int fileDesciptor, unsigned char hexaData)
{
	unsigned char ascii = 0x30 + hexaData;
	int bytes_written = write(fileDesciptor, &ascii, 1);
	tcdrain(fileDesciptor);
	//usleep(10000); 
}

