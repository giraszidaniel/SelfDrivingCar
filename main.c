#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <linux/joystick.h>
#include "joystick/Joystickfnctl.h"
#include "uart/uartfcntl.h"
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <signal.h>
#include "fpgaLoad/fpgaLoad.h"
#define BUFSIZE 1024
#define PORT_CPP 2223
#define PORT_PY 2222
struct joystickValues jV;

int main(int argc, char **argv)
{
	pid_t pid = fork();
	if (pid < 0)
	{
		perror("Fork sikertelen");
		exit(1);
	}
	else if(pid == 0)
	{
		execlp("python3","python3","web/webControlRpi.py",NULL);
		perror("Python kod elinditasa sikertelen");
		exit(6);
	}
	printf("Webkezelo elinditva");
	sleep(1);

	//int fileDescriptorRpi = system("python3 web/webControlRpi.py &");
    /*deklaracio socketnek*/
	int s;
	int bytes;
	int err;
	int flag;
	char on;
	char buffer[BUFSIZE];
	unsigned int server_size;
	struct sockaddr_in server;
    /*inicializacio socketnek CPP*/
	on = 1;
	flag = 0;
	server.sin_family = AF_INET;
	server.sin_addr.s_addr = inet_addr(argc == 1 ? "127.0.0.1" : argv[1]);
	server.sin_port = htons(PORT_PY);
	server_size = sizeof server;
	s = socket(AF_INET,SOCK_STREAM,0);
	if(s < 0)
	{
		fprintf(stderr,"%s: Socket error.\n", argv[0]);
		exit(2);
	}
	setsockopt(s,SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
	setsockopt(s,SOL_SOCKET, SO_KEEPALIVE, &on, sizeof on);

	err = connect(s, (struct sockaddr *) &server, server_size);
	if(err < 0)
	{
		fprintf(stderr, "%s: Connecting error.\n", argv[0]);
		exit(3);
	}
	printf("Connection is OK.\n");
	int s_compV;
	int bytes_compV;
	char buffer_compV[BUFSIZE];
	/*egyeb inicializalasok*/
	int js = Joystick_init(&jV);
	int uart_fd = uartInit();
	pid_t pidComputerV = -1;
	char computerVisionState = '0';
	int mode = 0;
	fpgaLoad(argv[2]);
	calibrateMotors(uart_fd);
	/*if (js < 0)
	{
		perror("Hiba");
		return 1;
	}*/
	//struct joystickValues jV;
	fcntl(s,F_SETFL, O_NONBLOCK);
	char last_sent_state = ' ';
	char last_sent_state_compV = ' ';
	while(1)
	{
		bytes = recv(s,buffer,BUFSIZE, flag);
		if (bytes < 0)
		{
			//fprintf(stdout,"%s: Nincs uj uzenet.\n", argv[0]);
			
		}
		//printf("Server's (%s:%d) acknowledgement:\n %s\n", inet_ntoa(server.sin_addr), ntohs(server.sin_port),buffer);
		if (bytes > 0)
		{
			 buffer[bytes] = '\0';
			if (buffer[0] == '1') mode = 1;
			else if(buffer[0] == '2') mode = 2;
			buffer[0] = '\0';
		}
//		printf("Server's acknowledgement %s\n",buffer);
		if (mode == 1)//taviranyitas
		{
		if (computerVisionState == '1')
		{
			close(s_compV);
			kill(pidComputerV, SIGTERM);
			computerVisionState = '0';
			pidComputerV = -1;
		}
		jV = readValues(js);
		printf("X: %6d\t Y: %6d\n", jV.axis[3], jV.axis[1]);
		fflush(stdout);
		usleep(10);
		unsigned char current_state = 0;
		if(jV.axis[3] <= 2000 && jV.axis[3] >= -2000 && jV.axis[1] >= -2000 && jV.axis[1] <= 2000) current_state = 0 ; // joystickok nincsenek elmozditva
		else if(jV.axis[3] <= 2000 && jV.axis[3] >= -2000 && jV.axis[1] <= -2001 && jV.axis[1] >= -10000) current_state = 1; // elore menetel egyes fokozat
		else if(jV.axis[3] <= 2000 && jV.axis[3] >= -2000 && jV.axis[1] <= -10001 && jV.axis[1] >= -20000) current_state = 2; // elore menetel kettes fokozat
		else if(jV.axis[3] <= 2000 && jV.axis[3] >= -2000 && jV.axis[1] <= -20001) current_state = 3;	//elore menetel harmas fokozat
		else if(jV.axis[3] >= 20000 && jV.axis[1] >= -2000 && jV.axis[1] <= 2000) current_state = 4; //jobbra megfordul
		else if(jV.axis[3] <= -20000 && jV.axis[1] >= -2000 && jV.axis[1] <= 2000) current_state = 5; //balra fordul
		else if( jV.axis[1] <= -10001 && jV.axis[1] >=- 20000 && jV.axis[3] <= -20000) current_state = 6;
		else if(jV.axis[3] >= 20000 && jV.axis[1] >= -10001 && jV.axis[1] >= -20000) current_state = 7;
		if (current_state != last_sent_state)
		{
			uartTransmitter(uart_fd,current_state);
			last_sent_state = current_state;
		}
		}
		else if(mode == 2)
		{
		unsigned char current_state_compV = 0;
		//CPP kodbol a pixelek elterese lesz megadva es annak huzok meg savokat
		if(computerVisionState == '0'){
			pidComputerV = fork();
			if (pidComputerV < 0)
			{
				perror("Fork sikertelen a savtartonak");
			}
			else if(pidComputerV == 0)
			{
				int log_fd = open("savtarto_error.log", O_WRONLY | O_CREAT | O_TRUNC, 0666);
				if (log_fd >= 0)
				{
					dup2(log_fd, STDOUT_FILENO);
					dup2(log_fd, STDERR_FILENO);
					close(log_fd);
				}
				chdir("./camera_handling");
				setenv("DISPLAY",":0",1);
				execlp("./savtarto", "./savtarto","127.0.0.1", NULL);
				perror("savtartas inditasa sikertelen");
				exit(8);
			}
			else
			{
				printf("Savtarto elindult: (PID: %d)", pidComputerV);
				//computerVisionState = '1';
//				if (buffer[0] == '1') kill(pidComputerV, SIGKILL);
				usleep(500000);
				struct sockaddr_in server_compV;
				server_compV.sin_family = AF_INET;
				server_compV.sin_addr.s_addr = inet_addr(argc == 1 ? "127.0.0.1" : argv[1]);
				server_compV.sin_port = htons(PORT_CPP);
				s_compV = socket(AF_INET, SOCK_STREAM, 0);
				if(s_compV < 0)
				{
					fprintf(stderr, "%s: Socket error!\n",argv[1]);
					exit(4);
				}
				else
				{
					setsockopt(s_compV, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
					setsockopt(s_compV, SOL_SOCKET, SO_KEEPALIVE, &on, sizeof on);
					if (connect(s_compV, (struct sockaddr *) &server_compV, sizeof(server_compV)) < 0)
					{
						fprintf(stderr, "C++ kapcsolodasi hiba");
						close(s_compV);
					}
					else
					{
						printf("C++ halozat pipa");
						fcntl(s_compV, F_SETFL, O_NONBLOCK);
						computerVisionState = '1';
					}

				}
			}
			
		}
			if(computerVisionState == '1')
			{
				bytes_compV =recv(s_compV, buffer_compV, BUFSIZE-1, flag);
				if (bytes_compV > 0)
				{
					buffer_compV[bytes_compV] = '\0';
					int steering_error = atoi(buffer_compV);
					if (steering_error == 0) current_state_compV = 0;
					else if (steering_error > 15 ) current_state_compV = 7;
					else if(steering_error < -15) current_state_compV = 6;
					else if(steering_error < 15 && steering_error >-15) current_state_compV = 3;
					
					if (current_state_compV != last_sent_state_compV)
					{
						uartTransmitter(uart_fd, current_state_compV);
						last_sent_state_compV = current_state_compV;
					}
				}
				else if(bytes_compV == 0)
				{
					printf("savtarto lekapcsolasa\n");
					close(s_compV);
					computerVisionState = '0';
				} 
			}
	}
		


		usleep(10000);

	}
	close(uart_fd);
	close(js);
	//close(computerVision);
	close(s);
	//close(fileDescriptorRpi);
	return 0;
}
