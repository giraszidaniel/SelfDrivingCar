#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/joystick.h>

int main() {

    int js;
    struct js_event event;

    int axis[8] = {0};
    int button[12] = {0};

    js = open("/dev/input/js0", O_RDONLY | O_NONBLOCK);

    if (js < 0) {
        perror("Joystick megnyitása sikertelen");
        return 1;
    }

    printf("Joystick olvasás...\n");

    while (1) {

        while (read(js, &event, sizeof(event)) > 0) {

            switch (event.type & ~JS_EVENT_INIT) {

                case JS_EVENT_AXIS:
                    axis[event.number] = event.value;
                    break;

                case JS_EVENT_BUTTON:
                    button[event.number] = event.value;
                    break;
            }
        }

        printf("X: %6d  Y: %6d\r", axis[3], axis[1]);
        fflush(stdout);

        usleep(1000); // 1ms = ~1000 Hz loop
    }

    close(js);
    return 0;
}
