#ifndef POM_ARM_H
#define POM_ARM_H

/**
 * PomArm
 *
 * A servo-driven arm that sweeps left/right to knock down pom poms.
 */
typedef struct PomArm {
	int servo_port;
	int sweep_left_position;
	int sweep_right_position;
	int stow_position;
	int sweep_pause_ms;

	/**
	 * Perform one left/right sweep motion.
	 */
	void (*sweep)();

	/**
	 * Move the arm to stow and disable the servo.
	 */
	void (*stop)();
} PomArm;

/**
 * Create an instance of PomArm with explicit configuration.
 */
extern PomArm new_pom_arm(int servo_port,
						  int sweep_left_position,
						  int sweep_right_position,
						  int stow_position,
						  int sweep_pause_ms);

/**
 * Create an instance of PomArm using values from PomArmConstants.h.
 */
extern PomArm new_default_pom_arm();

extern PomArm pom_arm;

#endif