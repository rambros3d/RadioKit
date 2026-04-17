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
RK_SlideSwitch slideSw({.label = "Power",
                        .icon = "power",
                        .x = 20,
                        .y = 40,
                        .aspect = 2.5f,
                        .state = false,
                        .onText = "ON",
                        .offText = "OFF"});
RK_Slider sld({.label = "Level",
               .x = 100,
               .y = 50,
               .rotation = 45,
               .aspect = 8.0f,
               .value = 12});
RK_Joystick joy({.label = "Stick", .x = 160, .y = 50, .scale = 2.0f});
RK_MultipleButton mode({.label = "Multiple Button",
                        .x = 60,
                        .y = 30,
                        .items = {{.label = "Auto", .icon = "cpu"},
                                  {.label = "Man", .icon = "hand"}}});
RK_MultipleSelect opts({.label = "Multiple Select",
                        .x = 60,
                        .y = 90,
                        .items = {{.label = "Log", .icon = "file-text"},
                                  {.label = "Mute", .icon = "volume-x"}}});
RK_LED statusLED({.label = "Status", .x = 20, .y = 20, .scale = 1.4f});
RK_Text uptimeText({.label = "Uptime", .x = 20, .y = 10});

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  RadioKit.config.name = "Serial Test v2.0";
  RadioKit.config.description = "USB Serial Connection Test Example";
  RadioKit.config.theme = RK_DEFAULT;
  RadioKit.config.password = "1234";

  RadioKit.begin();
  RadioKit.startSerial(Serial);
  Serial.println("RADIOKIT_READY");
}

void loop() {
  RadioKit.update();

  // Simple heartbeat on LED_PIN
  static uint32_t lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 1000) {
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    lastHeartbeat = millis();
  }

  // LED control: Button or switches can turn on the LED
  bool ledActive = btn.isPressed() || sw.get() || slideSw.get();
  digitalWrite(LED_PIN, ledActive ? HIGH : LOW);

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
