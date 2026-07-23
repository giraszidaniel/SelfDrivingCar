#include "fpgaLoad.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include "/home/dani1234/remote_control/uart/uartfcntl.h"

void fpgaLoad(char* input)
{
	char command[512];
	snprintf(command,sizeof(command),"openFPGALoader -b basys3 %s",input);
	int status = system(command);
	if(status == 0)
	{
		printf("Sikeres feltoltes fpgara\n");
		sleep(2);
	//	pid_t ppid = getppid();
	//	kill(ppid,SIGKILL);
	}
	else
	{
		printf("Hiba a feltoltes soran\n");
		exit(9);
	}
}

void calibrateMotors(int uart_fd)
{
	printf("kalibralas folyamatban...\n");
	uartTransmitter(uart_fd,'3');
	sleep(3);
	uartTransmitter(uart_fd,'0');
	sleep(3);
}
