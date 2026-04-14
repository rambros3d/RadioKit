/**
 * JoystickMotor — RadioKit Example
 *
 * A joystick in the app drives two DC motors using differential steering:
 *   Y axis  → forward / reverse
 *   X axis  → left / right mix
 *
 * A button acts as an emergency stop (toggle).
 * An LED shows direction: GREEN=fwd, RED=rev, YELLOW=turn, OFF=stopped.
 * A text widget shows speed as a percentage.
 *
 * Hardware:
 *   - ESP32 dev board
 *   - L298N (or similar) dual H-bridge motor driver
 *     Left  motor ENA → GPIO 25
 *     Right motor ENB → GPIO 26
 *     Direction IN pins wired per your driver board
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Connect to "RobotDrive" in the RadioKit app
 *   3. Use the joystick to drive; tap E-Stop to halt
 *
 * Swap startBLE → startSerial(Serial) for USB testing.
 */

#include <Arduino.h>
#include <RadioKit.h>

// ── Pin definitions ───────────────────────────────────────────
#define PWM_LEFT_PIN  25
#define PWM_RIGHT_PIN 26

// ── Widget declarations ───────────────────────────────────────────
//                           label      x    y  size
RadioKit_Joystick drive     ("Drive",  160,  50,  60);
RadioKit_Button   eStop     ("E-Stop",  20,  50,  24);
RadioKit_LED      dirLED    (           20,  20,  14);
RadioKit_Text     speedText ("Speed",  100,  20,  10);

// ── State ────────────────────────────────────────────────────────────
bool emergencyStop = false;

// ────────────────────────────────────────────────────────────
void setup() {
    pinMode(PWM_LEFT_PIN,  OUTPUT);
    pinMode(PWM_RIGHT_PIN, OUTPUT);
    analogWrite(PWM_LEFT_PIN,  0);
    analogWrite(PWM_RIGHT_PIN, 0);

    RadioKit.startBLE("RobotDrive");
    // RadioKit.startSerial(Serial);   // ← swap for USB testing
}

// ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();

    // Emergency stop toggle on each press
    if (eStop.isPressed()) {
        emergencyStop = !emergencyStop;
    }

    if (emergencyStop) {
        analogWrite(PWM_LEFT_PIN,  0);
        analogWrite(PWM_RIGHT_PIN, 0);
        dirLED.set(RadioKit_LED::RED);
        speedText.set("E-STOP");
        return;
    }

    // Read joystick axes (-100..+100)
    int8_t jx = drive.getX();
    int8_t jy = drive.getY();

    // Differential mixing
    int leftVal  = constrain((int)jy + (int)jx, -100, 100);
    int rightVal = constrain((int)jy - (int)jx, -100, 100);

    analogWrite(PWM_LEFT_PIN,  (uint8_t)map(abs(leftVal),  0, 100, 0, 255));
    analogWrite(PWM_RIGHT_PIN, (uint8_t)map(abs(rightVal), 0, 100, 0, 255));

    // Direction LED
    if (jx == 0 && jy == 0) {
        dirLED.set(RadioKit_LED::OFF);
    } else if (abs(jx) > abs(jy)) {
        dirLED.set(RadioKit_LED::YELLOW);
    } else if (jy > 0) {
        dirLED.set(RadioKit_LED::GREEN);
    } else {
        dirLED.set(RadioKit_LED::RED);
    }

    // Speed text
    int speed = max(abs((int)jx), abs((int)jy));
    char buf[24];
    if      (jy > 0)  snprintf(buf, sizeof(buf), "Fwd %d%%",            speed);
    else if (jy < 0)  snprintf(buf, sizeof(buf), "Rev %d%%",            speed);
    else if (jx != 0) snprintf(buf, sizeof(buf), "%s %d%%", jx > 0 ? "Right" : "Left", speed);
    else              snprintf(buf, sizeof(buf), "Stopped");
    speedText.set(buf);
}
