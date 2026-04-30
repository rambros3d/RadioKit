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
#define SECOND_LED_PIN 8

// ── Widget declarations (self-register on construction) ────────────────
// 1. Create a toggle button widget. We use a Props struct for initialization.
RK_ToggleButton lightSwitch(
    {.label = "Main Switch", .x = 100, .y = 50, .onText = "ON", .offText = "OFF"});

// New PushButton for pin 8
RK_PushButton momentButton(
    {.label = "Momentary", .x = 100, .y = 100});

// 2. Create LED status indicators.
RK_LED statusLED(
    {.label = "Main Status", .x = 20, .y = 20, .red = 0, .green = 255, .blue = 0});

RK_LED secondLED(
    {.label = "Pin 8 Status", .x = 20, .y = 50, .red = 0, .green = 0, .blue = 255});

// 3. Create a text label to show the state.
RK_Text stateText({.label = "Main State", .x = 100, .y = 20});

// ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000); // Give time for USB Serial to connect
  Serial.println("--- RadioKit BasicSwitch Start ---");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  pinMode(SECOND_LED_PIN, OUTPUT);
  digitalWrite(SECOND_LED_PIN, LOW);

  // Initialize RadioKit and start BLE advertising.
  Serial.println("RK: Initializing...");
  RadioKit.begin();
  
  Serial.println("RK: Starting BLE...");
  RadioKit.startBLE("LightSwitch");

  // Initial states
  statusLED.off();
  secondLED.off();
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

  // Handle the momentary pushbutton for pin 8
  if (momentButton.get()) {
    digitalWrite(SECOND_LED_PIN, HIGH);
    secondLED.on();
  } else {
    digitalWrite(SECOND_LED_PIN, LOW);
    secondLED.off();
  }
}
