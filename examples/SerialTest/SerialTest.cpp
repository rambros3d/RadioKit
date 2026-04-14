/**
 * SerialTest — RadioKit Example
 *
 * Minimal USB Serial sketch for testing the RadioKit app
 * over Web Serial (Chrome / Edge) or Android USB OTG.
 *
 * No BLE hardware or antenna required — great for rapid
 * layout and widget testing on a dev board.
 *
 * Widgets:
 *   - Button  → blinks built-in LED on each press
 *   - Switch  → toggles built-in LED continuously
 *   - Slider  → value echoed on serial monitor
 *   - Joystick→ X/Y echoed on serial monitor
 *   - LED     → cycles GREEN / YELLOW / RED based on slider value
 *   - Text    → shows uptime in seconds
 *
 * Hardware:
 *   - Any ESP32 dev board connected via USB
 *   - Built-in LED on GPIO 7 (change LED_PIN if needed)
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit app → choose "USB / Serial" connection
 *   3. Select the COM port → connect
 *   4. Interact with widgets
 *
 * Note: the USB serial port is shared with the RadioKit protocol.
 * Do NOT open the Arduino Serial Monitor while the app is connected.
 */

#include <Arduino.h>
#include <RadioKit.h>

// ── Pin definitions ───────────────────────────────────────────
#define LED_PIN 7

// ── Widget declarations ───────────────────────────────────────────
//                          label        x    y  size
RadioKit_Button btn("Press", 20, 50, 20);
RadioKit_Switch sw("LED", 60, 80, 20);
RadioKit_Slider sld("Level", 100, 50, 12, 8.0);
RadioKit_Joystick joy("Stick", 160, 50, 40);
RadioKit_LED statusLED(20, 20, 14);
RadioKit_Text uptimeText("Uptime", 80, 20, 10);

// ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // USB Serial transport — app connects over Web Serial or Android USB
  RadioKit.startSerial(Serial);
}

// ────────────────────────────────────────────────────────────
void loop() {
  RadioKit.update();

  // Button: blink LED on press
  if (btn.isPressed()) {
    digitalWrite(LED_PIN, HIGH);
    delay(80);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // Switch: hold LED on
  if (sw.isOn()) {
    digitalWrite(LED_PIN, HIGH);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // Status LED: reflects slider level
  uint8_t level = sld.value();
  if (level < 34)
    statusLED.set(RadioKit_LED::RED);
  else if (level < 67)
    statusLED.set(RadioKit_LED::YELLOW);
  else
    statusLED.set(RadioKit_LED::GREEN);

  // Uptime text (updates every second)
  static uint32_t lastSec = 0;
  uint32_t nowSec = millis() / 1000;
  if (nowSec != lastSec) {
    lastSec = nowSec;
    char buf[20];
    snprintf(buf, sizeof(buf), "%lus", (unsigned long)nowSec);
    uptimeText.set(buf);
  }
}
