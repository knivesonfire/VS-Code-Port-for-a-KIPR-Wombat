#include <kipr/wombat.h>

#include "PomArm.h"
#include "PomArmConstants.h"
#include "Controller.h"

PomArm pom_arm;

static int clamp_servo_position(int position) {
	if (position < 0) {
		return 0;
	}
	if (position > 2047) {
		return 2047;
	}
	return position;
}

static void sweep() {
	controller.enable_servo(pom_arm.servo_port);

	controller.servo(pom_arm.servo_port, pom_arm.sweep_left_position);
	msleep(pom_arm.sweep_pause_ms);

	controller.servo(pom_arm.servo_port, pom_arm.sweep_right_position);
	msleep(pom_arm.sweep_pause_ms);
}

static void stop() {
	controller.enable_servo(pom_arm.servo_port);
	controller.servo(pom_arm.servo_port, pom_arm.stow_position);
	msleep(pom_arm.sweep_pause_ms);
	controller.disable_servo(pom_arm.servo_port);
}

PomArm new_pom_arm(int servo_port,
				   int sweep_left_position,
				   int sweep_right_position,
				   int stow_position,
				   int sweep_pause_ms) {
	PomArm instance = {
		.servo_port = servo_port,
		.sweep_left_position = clamp_servo_position(sweep_left_position),
		.sweep_right_position = clamp_servo_position(sweep_right_position),
		.stow_position = clamp_servo_position(stow_position),
		.sweep_pause_ms = (sweep_pause_ms < 0) ? 0 : sweep_pause_ms,
		.sweep = &sweep,
		.stop = &stop,
	};

	return instance;
}

PomArm new_default_pom_arm() {
	return new_pom_arm(
		POM_ARM_SERVO_PORT,
		POM_ARM_SWEEP_LEFT_POSITION,
		POM_ARM_SWEEP_RIGHT_POSITION,
		POM_ARM_STOW_POSITION,
		POM_ARM_SWEEP_PAUSE_MS
	);
}
