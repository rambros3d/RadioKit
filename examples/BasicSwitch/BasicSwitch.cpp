/**
 * BasicSwitch — RadioKit Example
 *
 * Demonstrates the simplest RadioKit setup:
 *   - A toggle switch controls the built-in LED
 *   - An LED widget mirrors the physical LED state in the app
 *   - A text widget shows "ON" or "OFF"
 *
 * Hardware:
 *   - ESP32 dev board (built-in LED on GPIO 2)
 *   - No external components needed
 *
 * Wiring: none — uses the onboard LED
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit app and connect to "LightSwitch"
 *   3. Tap the switch to toggle the LED
 *
 * To test over USB instead of BLE, comment out startBLE() and
 * uncomment startSerial() — no other changes needed.
 */

#include <Arduino.h>
#include <RadioKit.h>

// ── Pin definitions ───────────────────────────────────────────
#define LED_PIN 7 // Built-in LED on most ESP32 dev boards

// ── Widget declarations (self-register on construction) ────────────────
//                          label      x    y   size  aspect
RadioKit_Switch lightSwitch("Light", 100, 50, 20);
RadioKit_LED statusLED(20, 20, 14);
RadioKit_Text stateText("State", 100, 20, 10);

// ────────────────────────────────────────────────────────────
void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  RadioKit.startBLE("LightSwitch");

  // To test over USB Serial: comment out startBLE and uncomment these:
  // Serial.begin(115200);
  // RadioKit.startSerial(Serial);
}

// ────────────────────────────────────────────────────────────
void loop() {
  RadioKit.update();

  if (lightSwitch.isOn()) {
    digitalWrite(LED_PIN, HIGH);
    statusLED.set(RadioKit_LED::GREEN);
    stateText.set("ON");
  } else {
    digitalWrite(LED_PIN, LOW);
    statusLED.set(RadioKit_LED::OFF);
    stateText.set("OFF");
  }
}
