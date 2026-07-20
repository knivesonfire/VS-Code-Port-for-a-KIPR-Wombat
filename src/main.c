#include <kipr/wombat.h>

#include <limits.h>
#include <stdio.h>
#include <unistd.h>
#include "constants/DriveConstants.h"
#include "Controller.h"
#include "PomArm.h"

Controller controller;
int main() {
    printf("Hello World!\n");
    controller = new_controller(
        LEFT_MOTOR_PORT,
        RIGHT_MOTOR_PORT,
        LEFT_MOTOR_INVERTED,
        RIGHT_MOTOR_INVERTED,
        MOTOR_DISTANCE,
        WHEEL_DIAMETER
    );

    pom_arm = new_default_pom_arm();

    controller.forward(10, 20.0f);
    pom_arm.sweep();
    pom_arm.stop();

    printf("Done moving!\n");
    return 0;
}
