#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/joystick.h>
#include "Joystickfnctl.h"

int Joystick_init()
{
	
    int js;

    js = open("/dev/input/js0", O_RDONLY | O_NONBLOCK);

    if (js < 0) {
        perror("Joystick megnyitása sikertelen");
        return 1;
    }

    printf("Joystick olvasás...\n");
    return js;
}

/*
void readJoystickValue()
{
	int axis[8] = {0};
    int button[12] = {0};
}
*/


struct joystickValues readValues(int fileDesciptor)
{
		static struct joystickValues newValues;
		struct js_event event;

		 while (read(fileDesciptor, &event, sizeof(event)) > 0) {

            switch (event.type & ~JS_EVENT_INIT) {

                case JS_EVENT_AXIS:
                    //axis[event.number] = event.value;
                    newValues.axis[event.number] = event.value;
                    break;

                case JS_EVENT_BUTTON:
                    newValues.button[event.number] = event.value;
                    break;
            }
        }
		return newValues;
}
