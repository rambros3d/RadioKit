/**
 * JoystickMotor — RadioKit Example
 *
 * A joystick in the app drives two DC motors (differential steering).
 *   Joystick Y axis   → forward / reverse speed
 *   Joystick X axis   → left / right mixing
 *
 * A button widget acts as an emergency stop (cuts both motors).
 *
 * An LED widget shows the current movement direction:
 *   GREEN  → moving forward
 *   RED    → moving backward
 *   YELLOW → turning
 *   OFF    → stopped / emergency stop active
 *
 * A text widget shows speed as a percentage.
 *
 * Hardware:
 *   - ESP32 dev board
 *   - L298N (or similar) dual H-bridge motor driver
 *     Left  motor ENA  → PWM_LEFT_PIN  (GPIO 25)
 *     Right motor ENB  → PWM_RIGHT_PIN (GPIO 26)
 *     Direction pins not shown — adapt to your motor driver board
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit Flutter app and scan for "RobotDrive"
 *   3. Use the joystick to drive; tap E-Stop to halt
 */

#include <RadioKit.h>

// ── Pin definitions ──────────────────────────────────────────────────────────
#define PWM_LEFT_PIN  25   // PWM output for left motor speed
#define PWM_RIGHT_PIN 26   // PWM output for right motor speed

// ── Widget declarations ──────────────────────────────────────────────────────
RadioKit_Joystick joystick;   // input  — x,y each -100..+100
RadioKit_Button   eStop;      // input  — emergency stop
RadioKit_LED      dirLED;     // output — movement direction indicator
RadioKit_Text     speedText;  // output — "Fwd 75%" etc.

// ── State ─────────────────────────────────────────────────────────────────
bool emergencyStop = false;

// ── Helpers ──────────────────────────────────────────────────────────────────
// Map a signed -100..+100 joystick value to an unsigned 0..255 PWM value.
// Negative values map to 0 (motor driver handles direction via IN pins).
// This example uses speed magnitude only; direction wiring depends on driver.
uint8_t joyToPWM(int8_t val) {
    int magnitude = abs((int)val);           // 0..100
    return (uint8_t)map(magnitude, 0, 100, 0, 255);
}

// ────────────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    Serial.println("RadioKit JoystickMotor example starting...");

    pinMode(PWM_LEFT_PIN,  OUTPUT);
    pinMode(PWM_RIGHT_PIN, OUTPUT);
    analogWrite(PWM_LEFT_PIN,  0);
    analogWrite(PWM_RIGHT_PIN, 0);

    // Register widgets
    //                   label           x    y    w    h
    RadioKit.addWidget(joystick,  "Drive",    50, 400, 400, 400);
    RadioKit.addWidget(eStop,     "E-Stop",  600, 400, 300, 300);
    RadioKit.addWidget(dirLED,    "Status",  550, 100, 200, 200);
    RadioKit.addWidget(speedText, "Speed",   500, 730, 400, 100);

    RadioKit.begin("RobotDrive");
    Serial.println("BLE advertising as 'RobotDrive'");
}

// ────────────────────────────────────────────────────────────────────────────
void loop() {
    RadioKit.handle();

    // ── Emergency stop ───────────────────────────────────────────────────────
    if (eStop.pressed()) {
        emergencyStop = !emergencyStop;  // toggle on each press
        Serial.print("E-Stop: ");
        Serial.println(emergencyStop ? "ACTIVE" : "CLEARED");
    }

    if (emergencyStop) {
        analogWrite(PWM_LEFT_PIN,  0);
        analogWrite(PWM_RIGHT_PIN, 0);
        dirLED.set(RadioKit_LED::RED);
        speedText.set("E-STOP");
        return;
    }

    // ── Read joystick ────────────────────────────────────────────────────────
    int8_t jx = joystick.x();  // -100..+100  (+ = right)
    int8_t jy = joystick.y();  // -100..+100  (+ = forward)

    // ── Differential mixing ──────────────────────────────────────────────────
    // left  = Y + X
    // right = Y - X
    // Clamp to -100..+100
    int leftVal  = constrain((int)jy + (int)jx, -100, 100);
    int rightVal = constrain((int)jy - (int)jx, -100, 100);

    uint8_t leftPWM  = (uint8_t)map(abs(leftVal),  0, 100, 0, 255);
    uint8_t rightPWM = (uint8_t)map(abs(rightVal), 0, 100, 0, 255);

    analogWrite(PWM_LEFT_PIN,  leftPWM);
    analogWrite(PWM_RIGHT_PIN, rightPWM);

    // ── Update direction LED ─────────────────────────────────────────────────
    if (jy == 0 && jx == 0) {
        dirLED.set(RadioKit_LED::OFF);
    } else if (abs(jx) > abs(jy)) {
        dirLED.set(RadioKit_LED::YELLOW);  // primarily turning
    } else if (jy > 0) {
        dirLED.set(RadioKit_LED::GREEN);   // forward
    } else {
        dirLED.set(RadioKit_LED::RED);     // reverse
    }

    // ── Update speed text ────────────────────────────────────────────────────
    int speed = max(abs((int)jx), abs((int)jy));
    char buf[24];
    if (jy > 0) {
        snprintf(buf, sizeof(buf), "Fwd %d%%", speed);
    } else if (jy < 0) {
        snprintf(buf, sizeof(buf), "Rev %d%%", speed);
    } else if (jx != 0) {
        snprintf(buf, sizeof(buf), "%s %d%%", (jx > 0 ? "Right" : "Left"), speed);
    } else {
        snprintf(buf, sizeof(buf), "Stopped");
    }
    speedText.set(buf);
}
