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
// Change this to match your specific board if needed.
#define LED_PIN 7

// ── Widget declarations (self-register on construction) ────────────────
// 1. Create a toggle button widget. We use a Props struct for initialization.
RK_ToggleButton lightSwitch(
    {.label = "Light", .x = 100, .y = 50, .onText = "ON", .offText = "OFF"});

// 2. Create an LED status indicator.
RK_LED statusLED(
    {.label = "Status", .x = 20, .y = 20, .red = 0, .green = 255, .blue = 0});

// 3. Create a text label to show the state.
RK_Text stateText({.label = "Current State", .x = 100, .y = 20});

// ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000); // Give time for USB Serial to connect
  Serial.println("--- RadioKit BasicSwitch Start ---");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize RadioKit and start BLE advertising.
  Serial.println("RK: Initializing...");
  RadioKit.begin();
  
  Serial.println("RK: Starting BLE...");
  RadioKit.startBLE("LightSwitch");

  // Initial states
  statusLED.off();
  stateText.set("OFF");
  
  Serial.println("RK: Setup complete.");
}

// ────────────────────────────────────────────────────────────
void loop() {
  // Always call update() to process incoming packets and manage connections.
  RadioKit.update();

  // Sync the physical LED and status widgets with the app switch state.
  if (lightSwitch.get()) {
    digitalWrite(LED_PIN, HIGH);
    statusLED.on();
    stateText.set("ON");
  } else {
    digitalWrite(LED_PIN, LOW);
    statusLED.off();
    stateText.set("OFF");
  }
}
