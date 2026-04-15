/**
 * SerialTest — RadioKit Example (v2.0)
 *
 * Minimal USB Serial sketch for testing the RadioKit app
 * over Web Serial (Chrome / Edge) or Android USB OTG.
 *
 * Wiring: LED anode → 220Ω → pin 7 → GND
 */

#include <Arduino.h>
#include <RadioKit.h>

#define LED_PIN 7

// ── Widget declarations ───────────────────────────────────────────
RK_PushButton   btn({ .label="Press",  .x=20,  .y=50, .scale=2.0f });
RK_ToggleButton sw ({  .label="LED",   .x=60,  .y=80, .scale=2.0f });
RK_Slider       sld({ .label="Level",  .x=100, .y=50, .aspect=8.0f, .value=12 });
RK_Joystick     joy({ .label="Stick",  .x=160, .y=50, .scale=4.0f });
RK_LED          statusLED({ .label="Status", .x=20,  .y=20, .scale=1.4f });
RK_Text         uptimeText({ .label="Uptime", .x=80,  .y=20 });

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  RadioKit.config.name     = "Serial Test v2.0";
  RadioKit.config.theme    = RK_DEFAULT;
  RadioKit.config.password = "1234";

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

void loop() {
  RadioKit.update();

  // Push button: blink LED on press
  if (btn.isPressed()) {
    digitalWrite(LED_PIN, HIGH);
    delay(80);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // Toggle switch: hold LED on
  if (sw.get()) {
    digitalWrite(LED_PIN, HIGH);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // Status LED reflects slider level
  uint8_t level = sld.get();
  if (level < 34) {
    statusLED.setColor(RK_RED);
  } else if (level < 67) {
    statusLED.setColor(RK_YELLOW);
  } else {
    statusLED.setColor(RK_GREEN);
  }

  // Uptime text updates every second
  static uint32_t lastSec = 0;
  uint32_t nowSec = millis() / 1000;
  if (nowSec != lastSec) {
    lastSec = nowSec;
    char buf[20];
    snprintf(buf, sizeof(buf), "%lus", (unsigned long)nowSec);
    uptimeText.set(buf);
  }
}
