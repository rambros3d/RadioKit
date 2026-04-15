# RadioKit Library — Function Reference

> This document reflects the **v2.0 Object-Oriented API** with the **Size & Aspect Ratio** layout model.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [Layout Model — Size & Aspect Ratio](#2-layout-model--size--aspect-ratio)
3. [Common Widget Methods](#3-common-widget-methods)
4. [Widget Class Reference](#4-widget-class-reference)
   - [RadioKit_Button](#radiokit_button)
   - [RadioKit_Switch](#radiokit_switch)
   - [RadioKit_Slider](#radiokit_slider)
   - [RadioKit_Joystick](#radiokit_joystick)
   - [RadioKit_LED](#radiokit_led)
   - [RadioKit_Text](#radiokit_text)
5. [RadioKit (Main Object)](#5-radiokit-main-object)
   - [startBLE()](#startble)
   - [startSerial()](#startserial)
   - [update()](#update)
   - [isConnected()](#isconnected)
6. [Coordinate System](#6-coordinate-system)
7. [Constants & Enums](#7-constants--enums)
8. [Full Sketch Example](#8-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a three-part pattern. Widgets **register themselves automatically** on construction — no `addWidget()` call needed.

```cpp
#include <RadioKit.h>

// ── 1. Widget declarations (global scope) ────────────────────────────────
RadioKit_Button  fireBtn("Fire", 20, 50, 20);
RadioKit_LED     status (        20, 20, 12);

// ── 2. setup() ───────────────────────────────────────────────────────────
void setup() {
    // BLE mode:
    RadioKit.startBLE("MyDevice");

    // — OR — USB Serial mode (Serial.begin must come first):
    // Serial.begin(115200);
    // RadioKit.startSerial(Serial);
}

// ── 3. loop() ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
    if (fireBtn.isPressed()) status.set(RadioKit_LED::GREEN);
}
```

> Switching between BLE and Serial requires changing only the `startXxx()` call (and adding `Serial.begin()`). All widget code is identical.

---

## 2. Layout Model — Size & Aspect Ratio

RadioKit uses a **Size + Aspect** model. The Arduino sends both values; the **app computes the final pixel dimensions**.

```
height = size
width  = size × (aspect / 10.0)     // computed by the app
```

### Wire Encoding

Aspect is transmitted as a `uint8_t` with **×10 scale** (range 0.0–25.5):

| Float | Wire `uint8_t` |
|---|---|
| 1.0 | 10 |
| 1.6 | 16 |
| 2.5 | 25 |
| 4.0 | 40 |
| 5.0 | 50 |
| 25.5 | 255 (max) |

### Aspect = 0 (Auto)

Passing `0` (the default) uses the widget's built-in default. `0` is resolved before transmission — the app never receives it.

| Widget | Default float | Wire value |
|---|---|---|
| `RadioKit_Button` | 2.5 | 25 |
| `RadioKit_Switch` | 1.6 | 16 |
| `RadioKit_Slider` | 5.0 | 50 |
| `RadioKit_Joystick` | 1.0 | 10 |
| `RadioKit_LED` | 1.0 | 10 |
| `RadioKit_Text` | 4.0 | 40 |

### Example

```cpp
RadioKit_Joystick joy(160, 50, 40);        // size=40, aspect=auto(1.0)  → 40×40
RadioKit_Slider   spd(100, 20, 10, 8.0);  // size=10, aspect=8.0 → wire 80 → 10×80
RadioKit_Button   btn(20,  50, 18, 3.0);  // size=18, aspect=3.0 → wire 30 → 18×54
```

---

## 3. Common Widget Methods

### `setPosition()`
```cpp
void setPosition(uint8_t x, uint8_t y);
void setPosition(uint8_t x, uint8_t y, int16_t rotation);
```

### `setSize()`
```cpp
void setSize(uint8_t size);                    // preserves current aspect
void setSize(uint8_t size, float aspectRatio); // changes both
```

### `setAspectRatio()`
```cpp
void setAspectRatio(float aspectRatio);  // 0 = revert to widget default
```

### `show()` / `hide()`
```cpp
void show();
void hide();
```

Hidden widgets are still included in protocol traffic — visibility is a hint to the app renderer.

---

## 4. Widget Class Reference

All constructors follow this pattern:

```cpp
WidgetType("label", x, y, size, aspectRatio = 0);  // with label
WidgetType(x, y, size, aspectRatio = 0);           // no label
```

| Parameter | Type | Description |
|---|---|---|
| `label` | `const char*` | Optional, max 32 chars |
| `x`, `y` | `uint8_t` | Center position on canvas (0–200) |
| `size` | `uint8_t` | Height in canvas units (0–200) |
| `aspectRatio` | `float` | `0` = widget default; stored as `uint8_t` ×10 internally |

---

### `RadioKit_Button`

Momentary push button. **Default aspect: 2.5** (wire: 25)

| Method | Returns | Description |
|---|---|---|
| `isPressed()` | `bool` | `true` once on the leading edge; auto-clears on read |
| `isHeld()` | `bool` | `true` continuously while the button is held |

```cpp
RadioKit_Button fire("Fire", 20, 50, 20);
if (fire.isPressed()) launch();
if (fire.isHeld())    keepFiring();
```

---

### `RadioKit_Switch`

Toggle switch — stays ON or OFF between interactions. **Default aspect: 1.6** (wire: 16)

| Method | Returns | Description |
|---|---|---|
| `isOn()` | `bool` | `true` = switch is ON |

```cpp
RadioKit_Switch light("Light", 60, 50, 16);
digitalWrite(RELAY_PIN, light.isOn() ? HIGH : LOW);
```

---

### `RadioKit_Slider`

Linear slider, returns 0–100. **Default aspect: 5.0** (wire: 50)

| Method | Returns | Description |
|---|---|---|
| `value()` | `uint8_t` | Current position 0–100 |

```cpp
RadioKit_Slider speed("Speed", 100, 20, 10);
analogWrite(PWM_PIN, map(speed.value(), 0, 100, 0, 255));
```

---

### `RadioKit_Joystick`

2-axis joystick — always square. **Default aspect: 1.0** (wire: 10)

| Method | Returns | Description |
|---|---|---|
| `getX()` | `int8_t` | −100 (left) to +100 (right), 0 = center |
| `getY()` | `int8_t` | −100 (down) to +100 (up), 0 = center |

```cpp
RadioKit_Joystick drive("Drive", 160, 50, 35);
int left  = constrain(drive.getY() + drive.getX(), -100, 100);
int right = constrain(drive.getY() - drive.getX(), -100, 100);
```

---

### `RadioKit_LED`

Color indicator, Arduino → App only. **Default aspect: 1.0** (wire: 10) — renders as a circle.

| Method | Description |
|---|---|
| `set(color)` | Set color: `RadioKit_LED::OFF` / `RED` / `GREEN` / `BLUE` / `YELLOW` |
| `get()` | Returns current `RadioKit_LEDColor` |

```cpp
RadioKit_LED status(20, 20, 15);
status.set(RadioKit_LED::GREEN);
```

---

### `RadioKit_Text`

Text display panel, Arduino → App only. **Default aspect: 4.0** (wire: 40)

| Method | Description |
|---|---|
| `set(const char*)` | Update displayed string (max 31 chars + null terminator) |
| `set(const String&)` | Arduino `String` overload |
| `get()` | Returns `const char*` to internal buffer |

```cpp
RadioKit_Text sensor("Sensor", 100, 80, 15);
char buf[32];
snprintf(buf, 32, "A0=%d", analogRead(A0));
sensor.set(buf);
```

---

## 5. RadioKit (Main Object)

`RadioKit` is a global singleton instance of `RadioKitClass`.

### `startBLE()`

```cpp
void RadioKit.startBLE(const char* deviceName, const char* password = nullptr);
```

Initialises NimBLE and starts advertising. Call once at the end of `setup()`.

---

### `startSerial()`

```cpp
void RadioKit.startSerial(Stream& stream);
```

Attaches RadioKit to a pre-initialised serial stream. **The sketch must call `Serial.begin()` (or equivalent) before this function.**

| Parameter | Description |
|---|---|
| `stream` | Any Arduino `Stream`: `Serial`, `Serial1`, `SoftwareSerial`, … |

`isConnected()` returns `true` for **3 seconds** after the last valid packet. The app must send `PING` at least every 2 s to maintain the session.

```cpp
// USB Serial (Chrome Web Serial / Android USB OTG)
void setup() {
    Serial.begin(115200);
    RadioKit.startSerial(Serial);
}

// Hardware UART
void setup() {
    Serial1.begin(9600, SERIAL_8N1, RX_PIN, TX_PIN);
    RadioKit.startSerial(Serial1);
}
```

---

### `update()`

```cpp
void RadioKit.update();
```

Polls the active transport for incoming packets and drives BLE housekeeping. **Must be called once every `loop()` iteration.**

---

### `isConnected()`

```cpp
bool RadioKit.isConnected() const;
```

| Transport | Behaviour |
|---|---|
| BLE | `true` while a peer is connected; `false` after disconnect |
| Serial | `true` for 3 s after last valid packet; `false` at boot until first packet |

---

## 6. Coordinate System

```
(0,200) ┌──────────────────────────┐ (200,200)
        │  Y increases ↑          │
        │  X increases →          │
  (0,0) └──────────────────────────┘ (200,0)
```

- Origin `(0,0)` = bottom-left corner
- `x`, `y` = **center** of the widget
- Canvas range: **0–200** on both axes

---

## 7. Constants & Enums

```cpp
enum RadioKit_Orientation : uint8_t {
    RK_LANDSCAPE = 0x00,
    RK_PORTRAIT  = 0x01
};

enum RadioKit_LEDColor : uint8_t {
    RK_LED_OFF    = 0,
    RK_LED_RED    = 1,
    RK_LED_GREEN  = 2,
    RK_LED_BLUE   = 3,
    RK_LED_YELLOW = 4
};

#define RADIOKIT_MAX_WIDGETS  16   // max widgets per sketch
#define RADIOKIT_MAX_LABEL    32   // max label length (chars)
#define RADIOKIT_TEXT_LEN     32   // RadioKit_Text buffer size (31 chars + null)
```

---

## 8. Full Sketch Example

```cpp
#include <RadioKit.h>

RadioKit_Joystick drive ("Drive",  160, 50, 35);
RadioKit_Slider   speed ("Speed",  100, 15, 10);
RadioKit_Switch   light ("Light",   60, 50, 16);
RadioKit_Button   honk  ("Honk",    20, 50, 20);
RadioKit_LED      status(           20, 20, 12);
RadioKit_Text     sensor("Sensor", 100, 80, 12);

void setup() {
    RadioKit.startBLE("RoboCar");
    // — or for USB testing —
    // Serial.begin(115200);
    // RadioKit.startSerial(Serial);
}

void loop() {
    RadioKit.update();

    if (!RadioKit.isConnected()) {
        status.set(RadioKit_LED::OFF);
        return;
    }

    int spd   = speed.value();
    int left  = constrain(drive.getY() + drive.getX(), -100, 100);
    int right = constrain(drive.getY() - drive.getX(), -100, 100);
    analogWrite(LEFT_MOTOR,  map(left  * spd / 100, -100, 100, 0, 255));
    analogWrite(RIGHT_MOTOR, map(right * spd / 100, -100, 100, 0, 255));

    digitalWrite(RELAY_PIN, light.isOn()  ? HIGH : LOW);
    digitalWrite(HORN_PIN,  honk.isHeld() ? HIGH : LOW);

    if      (abs(drive.getX()) > 50 || abs(drive.getY()) > 50)
        status.set(RadioKit_LED::GREEN);
    else if (light.isOn())
        status.set(RadioKit_LED::YELLOW);
    else
        status.set(RadioKit_LED::BLUE);

    char buf[32];
    snprintf(buf, 32, "A0=%d  A1=%d", analogRead(A0), analogRead(A1));
    sensor.set(buf);
}
```
