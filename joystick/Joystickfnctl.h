#ifndef JOYSTICKFNCTL_H
#define JOYSTICKFNCTL_H
struct joystickValues
{
	int axis[8];
	int button[12];
};

int Joystick_init();
struct joystickValues readValues(int fileDescriptor);

#endif
