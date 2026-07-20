//
//  Controller.c
//  Source written by Justin Yu
//

#include "Controller.h"
#include <math.h>
#include <stdlib.h>

static void forward(float dist, float velocity_cm_per_sec);
static void backward(float dist, float velocity_cm_per_sec);
static void left(int angle, float radius, float velocity_cm_per_sec);
static void right(int angle, float radius, float velocity_cm_per_sec);
static void motor_velocity(int motor, int velocity_ticks_per_sec);

static int motor_direction(int motor);
static int clamp_velocity_ticks_per_sec(int velocity_ticks_per_sec);
static int cm_per_sec_to_ticks_per_sec(float velocity_cm_per_sec);
static void drive_motor_velocity(int motor, int velocity_ticks_per_sec);
static long signed_motor_position(int motor);

/**
 * Converts from centimeters to BackEMF ticks (robot measurement).
 * @param  cm a distance in centimeters that you want to convert
 * @return    the parameter `cm` in BackEMF ticks
 */
long CMtoBEMF(float cm) {
 	return (long)(cm * 1150. / (M_PI * controller.wheel_diameter));
}

/**
 * Converts from BackEMF ticks to centimeters.
 * @param  ticks a distance in BackEMF ticks that you want to convert
 * @return       the parameter `ticks` in centimeters
 */
float BEMFtoCM(long ticks) {
 	return (float)(ticks * (M_PI * controller.wheel_diameter) / 1100.);
}

static int motor_direction(int motor) {
    if (motor == controller.motor_left)
        return controller.motor_left_direction;
    if (motor == controller.motor_right)
        return controller.motor_right_direction;
    return 1;
}

static int clamp_velocity_ticks_per_sec(int velocity_ticks_per_sec) {
    const int max_velocity_ticks_per_sec = 1500;

    if (velocity_ticks_per_sec > max_velocity_ticks_per_sec)
        return max_velocity_ticks_per_sec;
    if (velocity_ticks_per_sec < -max_velocity_ticks_per_sec)
        return -max_velocity_ticks_per_sec;

    return velocity_ticks_per_sec;
}

static int cm_per_sec_to_ticks_per_sec(float velocity_cm_per_sec) {
    return CMtoBEMF(velocity_cm_per_sec);
}

static void drive_motor_velocity(int motor, int velocity_ticks_per_sec) {
    int signed_velocity = velocity_ticks_per_sec * motor_direction(motor);
    controller.mav(motor, clamp_velocity_ticks_per_sec(signed_velocity));
}

static void motor_velocity(int motor, int velocity_ticks_per_sec) {
    drive_motor_velocity(motor, velocity_ticks_per_sec);
}

static long signed_motor_position(int motor) {
    return (long)controller.gmpc(motor) * motor_direction(motor);
}

static void forward(float dist, float velocity_cm_per_sec) {
    if(dist < 0.) {
	backward(-dist, velocity_cm_per_sec);
      	return;
    }

    int velocity_ticks_per_sec = cm_per_sec_to_ticks_per_sec(fabsf(velocity_cm_per_sec));
    if (velocity_ticks_per_sec == 0)
        return;

  	// Calculate the # of ticks the robot must move for each wheel
	long ticks = CMtoBEMF(dist);
    long totalLeftTicks = signed_motor_position(controller.motor_left) + ticks;
    long totalRightTicks = signed_motor_position(controller.motor_right) + ticks;

  	// Start motors
    drive_motor_velocity(controller.motor_left, velocity_ticks_per_sec);
    drive_motor_velocity(controller.motor_right, velocity_ticks_per_sec);

  	// Keep moving until both motors reach their desired # of ticks
    while(signed_motor_position(controller.motor_left) < totalLeftTicks
          && signed_motor_position(controller.motor_right) < totalRightTicks) {
        if (signed_motor_position(controller.motor_left) >= totalLeftTicks)
			off(controller.motor_left);
        if (signed_motor_position(controller.motor_right) >= totalRightTicks)
			off(controller.motor_right);
	}

	off(controller.motor_left);
  	off(controller.motor_right);
}

static void backward(float dist, float velocity_cm_per_sec) {
    if(dist < 0.) {
        forward(-dist, velocity_cm_per_sec);
        return;
    }

    int velocity_ticks_per_sec = cm_per_sec_to_ticks_per_sec(fabsf(velocity_cm_per_sec));
    if (velocity_ticks_per_sec == 0)
        return;

  	// Calculate the # of ticks the robot must move for each wheel
	long ticks = CMtoBEMF(dist);
    long totalLeftTicks = signed_motor_position(controller.motor_left) - ticks;
    long totalRightTicks = signed_motor_position(controller.motor_right) - ticks;

  	// Start motors
    drive_motor_velocity(controller.motor_left, -velocity_ticks_per_sec);
    drive_motor_velocity(controller.motor_right, -velocity_ticks_per_sec);

  	// Keep moving until both motors reach their desired # of ticks
    while(signed_motor_position(controller.motor_left) > totalLeftTicks
          && signed_motor_position(controller.motor_right) > totalRightTicks) {
        if (signed_motor_position(controller.motor_left) <= totalLeftTicks)
			off(controller.motor_left);
        if (signed_motor_position(controller.motor_right) <= totalRightTicks)
			off(controller.motor_right);
	}
    off(controller.motor_left);
    off(controller.motor_right);
}

static void left(int angle, float radius, float velocity_cm_per_sec) {
    // calculate radii
    float left_radius = radius;
    float right_radius = radius + controller.distance_between_wheels;

    if(left_radius < 0)
        return;
    if(right_radius <= 0)
        return;

    // calculate distance in CM
    float right_distance = (right_radius * M_PI) * ((float)(angle) / 180.);

    // Scale wheel velocities based on turn radius to keep geometric arc tracking.
    float outer_velocity_cm_per_sec = fabsf(velocity_cm_per_sec);
    int right_velocity_ticks_per_sec = cm_per_sec_to_ticks_per_sec(outer_velocity_cm_per_sec);
    int left_velocity_ticks_per_sec =
        (int)((left_radius / right_radius) * (float)right_velocity_ticks_per_sec);

    if (right_velocity_ticks_per_sec == 0)
        return;

    long right_distance_ticks = CMtoBEMF(right_distance);

    // clear motor tick counter
    controller.cmpc(controller.motor_left);
    controller.cmpc(controller.motor_right);

    // power motors

    drive_motor_velocity(controller.motor_left, left_velocity_ticks_per_sec);
    drive_motor_velocity(controller.motor_right, right_velocity_ticks_per_sec);

    while(abs(controller.gmpc(controller.motor_right)) <= abs(right_distance_ticks)) {
        msleep(50);
    }

    off(controller.motor_left);
    off(controller.motor_right);
}


static void right(int angle, float radius, float velocity_cm_per_sec) {
	// calculate radii
    float left_radius = radius + controller.distance_between_wheels;
    float right_radius = radius;

    if(left_radius <= 0)
        return;
    if(right_radius < 0)
        return;

    // calculate distance in CM
    float left_distance = (left_radius * M_PI) * ((float)(angle) / 180.);

    // Scale wheel velocities based on turn radius to keep geometric arc tracking.
    float outer_velocity_cm_per_sec = fabsf(velocity_cm_per_sec);
    int left_velocity_ticks_per_sec = cm_per_sec_to_ticks_per_sec(outer_velocity_cm_per_sec);
    int right_velocity_ticks_per_sec =
        (int)((right_radius / left_radius) * (float)left_velocity_ticks_per_sec);

    if (left_velocity_ticks_per_sec == 0)
        return;

    long left_distance_ticks = CMtoBEMF(left_distance);

    // clear motor tick counter
    controller.cmpc(controller.motor_left);
    controller.cmpc(controller.motor_right);

    // power motors

    drive_motor_velocity(controller.motor_left, left_velocity_ticks_per_sec);
    drive_motor_velocity(controller.motor_right, right_velocity_ticks_per_sec);

    while(abs(controller.gmpc(controller.motor_left)) <= abs(left_distance_ticks)) {
        msleep(50);
    }

    off(controller.motor_left);
    off(controller.motor_right);
}

// FIX THIS
static void slow_servo(int port, int position, float time) {
    float increment = .01;
	float curr, start = controller.get_servo_position(port);
	float i = ((position - start) / time) * increment;
	curr = start;
	if (start > position)
	{
		while(curr > position)
		{
			controller.servo(port, curr);
			curr += i;
			msleep((long)(increment * 1000));
		}
	}
	else if (start < position)
	{
		while(curr < position)
		{
			controller.servo(port, curr);
			curr += i;
			msleep((long)(increment * 1000));
		}
	}
	controller.servo(port, position);
}

// Constructors

Controller new_controller(int motor_left, int motor_right,
              int motor_left_inverted, int motor_right_inverted,
              float distance_between_wheels, float wheel_diameter) {
	Controller instance = {

        // Instance Variables (with no setters)
    .motor_left = motor_left,
    .motor_right = motor_right,
    .motor_left_direction = motor_left_inverted ? -1 : 1,
    .motor_right_direction = motor_right_inverted ? -1 : 1,
        .distance_between_wheels = distance_between_wheels,
        .wheel_diameter = wheel_diameter,

        // Assign method references
        .forward = &forward, .backward = &backward,
        .left = &left, .right = &right,
        .motor = &motor_velocity,
        .mav = &mav, .mtp = &mtp, .mrp = &mrp,
        .stop = &ao,
        .motor_off = &off,
        .gmpc = &gmpc,
        .clear_motor_position_counter = &cmpc,
        .gmpc = &gmpc, .cmpc = &cmpc,
        .enable_servo = &enable_servo,
        .disable_servo = &disable_servo,
        .enable_servos = &enable_servos,
        .disable_servos = &disable_servos,
        .get_servo_position = &get_servo_position,
        .servo = &set_servo_position,
        .slow_servo = &slow_servo,
        .digital = &digital,
        .analog = &analog,
        .analog10 = &analog10,
        .analog_et = &analog_et
    };

    return instance;
}

Controller new_create_controller() {
	Controller instance = {
    .motor_left_direction = 1,
    .motor_right_direction = 1,
        // Assign method references
        .motor = &motor_velocity,
        .mav = &mav, .mtp = &mtp, .mrp = &mrp,
        .stop = &ao,
        .motor_off = &off,
        .gmpc = &gmpc,
        .clear_motor_position_counter = &cmpc,
        .gmpc = &gmpc, .cmpc = &cmpc,
        .enable_servo = &enable_servo,
        .disable_servo = &disable_servo,
        .enable_servos = &enable_servos,
        .disable_servos = &disable_servos,
        .get_servo_position = &get_servo_position,
        .servo = &set_servo_position,
        .slow_servo = &slow_servo,
        .digital = &digital,
        .analog = &analog,
        .analog10 = &analog10,
        .analog_et = &analog_et
    };
    return instance;
}