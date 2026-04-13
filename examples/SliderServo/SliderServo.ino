/**
 * SliderServo — RadioKit Example
 *
 * A slider in the app controls a servo motor angle (0°–180°).
 * A text widget displays the current angle.
 * An LED widget provides a visual zone indicator:
 *   0–30°  → RED    (left zone)
 *   31–150° → GREEN (centre zone)
 *   151–180°→ BLUE  (right zone)
 *
 * Hardware:
 *   - ESP32 dev board
 *   - Standard RC servo connected to SERVO_PIN
 *     (signal wire → GPIO 18, power → 5 V, GND → GND)
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit Flutter app and scan for "ServoControl"
 *   3. Move the slider — the servo follows
 */

#include <RadioKit.h>
#include <ESP32Servo.h>   // Install "ESP32Servo" library via Library Manager

// ── Pin definitions ──────────────────────────────────────────────────────────
#define SERVO_PIN 18

// ── Widget declarations ──────────────────────────────────────────────────────
RadioKit_Slider slider;    // input  — 0 to 100
RadioKit_Text   angleText; // output — displays "90°"
RadioKit_LED    zoneLED;   // output — indicates position zone

// ── Servo object ─────────────────────────────────────────────────────────────
Servo myServo;

// ── Helpers ──────────────────────────────────────────────────────────────────
// Map slider value (0-100) to servo angle (0-180)
int sliderToAngle(uint8_t sliderVal) {
    return map(sliderVal, 0, 100, 0, 180);
}

// ────────────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    Serial.println("RadioKit SliderServo example starting...");

    // Attach servo with standard 50 Hz timing
    myServo.attach(SERVO_PIN, 500, 2400); // min/max pulse in µs
    myServo.write(90); // centre on start-up

    // Register widgets
    //                 label         x    y    w     h
    RadioKit.addWidget(slider,    "Angle",   100, 400, 800, 120);
    RadioKit.addWidget(angleText, "Degrees", 350, 600, 300, 100);
    RadioKit.addWidget(zoneLED,   "Zone",    425, 200, 150, 150);

    RadioKit.begin("ServoControl");
    Serial.println("BLE advertising as 'ServoControl'");
}

// ────────────────────────────────────────────────────────────────────────────
void loop() {
    RadioKit.handle();

    // ── Compute angle from slider ────────────────────────────────────────────
    int angle = sliderToAngle(slider.value());

    // ── Drive servo ─────────────────────────────────────────────────────────
    myServo.write(angle);

    // ── Update text widget ───────────────────────────────────────────────────
    char buf[16];
    snprintf(buf, sizeof(buf), "%d deg", angle);
    angleText.set(buf);

    // ── Update zone LED ──────────────────────────────────────────────────────
    if (angle <= 30) {
        zoneLED.set(RadioKit_LED::RED);
    } else if (angle <= 150) {
        zoneLED.set(RadioKit_LED::GREEN);
    } else {
        zoneLED.set(RadioKit_LED::BLUE);
    }
}
