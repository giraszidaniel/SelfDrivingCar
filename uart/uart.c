#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <string.h>

int main() {
    const char *port_name = "/dev/ttyAMA0";

    int uart_fd = open(port_name, O_RDWR | O_NOCTTY | O_SYNC);
    if (uart_fd == -1) {
        perror("Hiba a port megnyitasakor");
        return 1;
    }

    struct termios options;
    memset(&options, 0, sizeof(options));

    if (tcgetattr(uart_fd, &options) != 0) {
        perror("tcgetattr hiba");
        close(uart_fd);
        return 1;
    }


    cfmakeraw(&options);

    cfsetispeed(&options, B9600);
    cfsetospeed(&options, B9600);

    options.c_cflag &= ~PARENB;   // nincs parit
    options.c_cflag &= ~CSTOPB;   // 1 stopbit
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;       // 8 adatbit
    options.c_cflag |= CLOCAL;    // Helyi vonal (nem figyel modem statuszt)
    options.c_cflag |= CREAD;     // Vtel engedlyezse

#ifdef CRTSCTS
    options.c_cflag &= ~CRTSCTS;  // Hardveres flow control kikapcsolsa
#endif

    // 4. ID
    options.c_cc[VMIN] = 0;
    options.c_cc[VTIME] = 5;

    tcflush(uart_fd, TCIOFLUSH);

    if (tcsetattr(uart_fd, TCSANOW, &options) != 0) {
        perror("tcsetattr hiba");
        close(uart_fd);
        return 1;
    }

    printf("Pi -> FPGA ASCII ado elinditva (Putty szimulacio)...\n");

    unsigned char hexa_ertek = 0;

    while (1) {
        unsigned char ascii_karakter = 0x30 + hexa_ertek; 

        int bytes_written = write(uart_fd, &ascii_karakter, 1);
        
        tcdrain(uart_fd); 

        if (bytes_written == 1) {
            printf("Kuldve ASCII karakter: %c (Hexa: 0x%02X)\n", ascii_karakter, ascii_karakter);
        } else {
            perror("Hiba a kuldes soran");
        }

        hexa_ertek++;
        if (hexa_ertek > 9) { // 0-9 
            hexa_ertek = 0;
        }

        sleep(1);
    }

    close(uart_fd);
    return 0;
}
