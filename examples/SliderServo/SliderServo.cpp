/**
 * SliderServo — RadioKit Example
 *
 * A slider in the app controls a servo motor angle (0–180°).
 * A text widget shows the current angle.
 * An LED indicates the position zone:
 *   0–30°   → RED   (left)
 *   31–150°  → GREEN (centre)
 *   151–180° → BLUE  (right)
 *
 * Hardware:
 *   - ESP32 dev board
 *   - Standard RC servo: signal → GPIO 18, power → 5 V, GND → GND
 *
 * Requires the "ESP32Servo" library (install via Library Manager).
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Connect to "ServoControl" in the RadioKit app
 *   3. Drag the slider to move the servo
 *
 * Swap startBLE → startSerial(Serial) for USB testing.
 */

#include <Arduino.h>
#include <RadioKit.h>
#include <ESP32Servo.h>

// ── Pin definitions ───────────────────────────────────────────
#define SERVO_PIN 18

// ── Widget declarations ───────────────────────────────────────────
//                        label       x    y  size
RadioKit_Slider servoSlider("Angle", 100,  50,  12, 8.0);  // wide bar
RadioKit_LED    zoneLED    (          20,  20,  14);
RadioKit_Text   angleText  ("Deg",    20,  80,  10);

// ── Servo object ───────────────────────────────────────────────────
Servo myServo;

// ────────────────────────────────────────────────────────────
void setup() {
    myServo.attach(SERVO_PIN, 500, 2400);
    myServo.write(90);  // centre on boot

    RadioKit.startBLE("ServoControl");
    // RadioKit.startSerial(Serial);   // ← swap for USB testing
}

// ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();

    int angle = map(servoSlider.value(), 0, 100, 0, 180);
    myServo.write(angle);

    // Angle text
    char buf[16];
    snprintf(buf, sizeof(buf), "%d deg", angle);
    angleText.set(buf);

    // Zone LED
    if      (angle <= 30)  zoneLED.set(RadioKit_LED::RED);
    else if (angle <= 150) zoneLED.set(RadioKit_LED::GREEN);
    else                   zoneLED.set(RadioKit_LED::BLUE);
}
