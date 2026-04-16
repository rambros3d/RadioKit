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
RK_PushButton
    btn({.label = "Press", .icon = "wifi", .x = 20, .y = 60, .scale = 2.0f});
RK_ToggleButton sw({.label = "LED", .x = 20, .y = 80, .scale = 2.0f});
RK_Slider sld({.label = "Level",
               .x = 100,
               .y = 50,
               .rotation = 45,
               .aspect = 8.0f,
               .value = 12});
RK_Joystick joy({.label = "Stick", .x = 160, .y = 50, .scale = 2.0f});
RK_MultipleButton mode({.label = "Mode",
                        .x = 60,
                        .y = 30,
                        .items = {{.label = "Auto", .icon = "cpu"},
                                  {.label = "Man", .icon = "hand"}}});
RK_MultipleSelect opts({.label = "Config",
                        .x = 60,
                        .y = 80,
                        .items = {{.label = "Log", .icon = "file-text"},
                                  {.label = "Mute", .icon = "volume-x"}}});
RK_LED statusLED({.label = "Status", .x = 20, .y = 40, .scale = 1.4f});
RK_Text uptimeText({.label = "Uptime", .x = 20, .y = 10});

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  RadioKit.config.name = "Serial Test v2.0";
  RadioKit.config.theme = RK_DEFAULT;
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
    char buf[32];
    const char *modeName = (mode.get() == 0) ? "AUTO" : "MAN";
    snprintf(buf, sizeof(buf), "%s | %lus", modeName, (unsigned long)nowSec);
    uptimeText.set(buf);
  }

  // Options logic: if Mute is active, turn off LED regardless of slider
  if (opts.get(1)) { // "Mute" is the second item (bit 1)
    statusLED.off();
  } else {
    statusLED.on();
  }
}
