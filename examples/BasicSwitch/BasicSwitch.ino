/**
 * BasicSwitch — RadioKit Example
 *
 * Demonstrates the simplest RadioKit setup:
 *   - A toggle switch controls the built-in LED
 *   - An LED widget in the app mirrors the physical LED state
 *   - A text widget displays "ON" or "OFF"
 *
 * Hardware:
 *   - ESP32 dev board (built-in LED on GPIO 2)
 *   - No external components needed
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit Flutter app and scan for "LightSwitch"
 *   3. Tap the switch to toggle the LED
 */

#include <RadioKit.h>

// ── Pin definitions ──────────────────────────────────────────────────────────
#define LED_PIN 2  // Built-in LED on most ESP32 boards

// ── Widget declarations ──────────────────────────────────────────────────────
RadioKit_Switch switchWidget;   // input  — user toggles in app
RadioKit_LED    ledWidget;      // output — shows LED state in app
RadioKit_Text   textWidget;     // output — shows "ON" or "OFF"

// ────────────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    Serial.println("RadioKit BasicSwitch example starting...");

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    // Register widgets (virtual 1000×1000 coordinate space)
    //                  label       x     y     w     h
    RadioKit.addWidget(switchWidget, "Light",  300, 200, 400, 150);
    RadioKit.addWidget(ledWidget,    "Status", 400, 450, 200, 200);
    RadioKit.addWidget(textWidget,   "State",  350, 700, 300, 100);

    // Initialise BLE — device name visible in the app's scan list
    RadioKit.begin("LightSwitch");

    Serial.println("BLE advertising as 'LightSwitch'");
}

// ────────────────────────────────────────────────────────────────────────────
void loop() {
    RadioKit.handle();  // must be called every iteration

    // ── Read input widget ────────────────────────────────────────────────────
    if (switchWidget.isOn()) {
        // Switch is ON — turn on physical LED and update output widgets
        digitalWrite(LED_PIN, HIGH);
        ledWidget.set(RadioKit_LED::GREEN);
        textWidget.set("ON");
    } else {
        // Switch is OFF
        digitalWrite(LED_PIN, LOW);
        ledWidget.set(RadioKit_LED::OFF);
        textWidget.set("OFF");
    }
}
