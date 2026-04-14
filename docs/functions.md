# RadioKit Library — Function Reference

> **Note:** This document reflects the **v2.0 Object-Oriented API** with the **Size & Aspect Ratio** layout model.

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
6. [Coordinate System](#6-coordinate-system)
7. [Constants & Enums](#7-constants--enums)
8. [Full Sketch Example](#8-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a simple three-part pattern. Widgets **register themselves automatically** on declaration — no `addWidget()` call needed.

```cpp
#include <RadioKit.h>

// ── Part 1: Widget declarations ──────────────────────────────────────────
// Format: ["Label",] x, y, size [, aspectRatio]
RadioKit_Button  fireBtn("Fire", 20, 50, 20);
RadioKit_LED     status (        20, 20, 12);

// ── Part 2: setup() ─────────────────────────────────────────────────────
void setup() {
    RadioKit.startBLE("MyDevice");
}

// ── Part 3: loop() ─────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
    if (fireBtn.isPressed()) status.set(RadioKit_LED::GREEN);
}
```

---

## 2. Layout Model — Size & Aspect Ratio

RadioKit uses a **Size + Aspect Ratio** model. The Arduino transmits both values; the **app is responsible for computing the final pixel dimensions**.

### Definitions

```
height = size
width  = size × (aspect / 10.0)     // computed by the app, not the Arduino
```

`size` maps to the widget **height** in canvas units. `aspect` controls the width relative to that height.

### Wire Encoding

Aspect ratio is transmitted as a `uint8_t` with **×10 scale**:

| Float ratio | Wire value (`uint8_t`) |
|---|---|
| 1.0 | 10 |
| 1.6 | 16 |
| 2.5 | 25 |
| 4.0 | 40 |
| 5.0 | 50 |
| 25.5 | 255 (max) |

The Arduino never multiplies `size × aspect`. It sends them as two separate bytes and leaves geometry to the app.

### Aspect Ratio = 0 (Auto)

Passing `0` (the default) in the constructor selects the widget’s **built-in default**:

| Widget | Default float ratio | Wire value |
|---|---|---|
| `RadioKit_Button` | 2.5 | 25 |
| `RadioKit_Switch` | 1.6 | 16 |
| `RadioKit_Slider` | 5.0 | 50 |
| `RadioKit_Joystick` | 1.0 | 10 |
| `RadioKit_LED` | 1.0 | 10 |
| `RadioKit_Text` | 4.0 | 40 |

`0` is resolved to the widget’s default **before** transmission — the app never receives `0`.

### Worked Example

```
RadioKit_Joystick joy(160, 50, 40);        // size=40, aspect=0 → wire: 10
// App: height = 40,  width = 40 × (10÷10.0) = 40  (square)

RadioKit_Slider   spd(100, 20, 10, 8.0);  // size=10, aspect=8.0 → wire: 80
// App: height = 10,  width = 10 × (80÷10.0) = 80  (long thin bar)

RadioKit_Button   btn(20,  50, 18, 3.0);  // size=18, aspect=3.0 → wire: 30
// App: height = 18,  width = 18 × (30÷10.0) = 54  (wide button)
```

---

## 3. Common Widget Methods

### `setPosition()`

```cpp
void setPosition(uint8_t x, uint8_t y);
void setPosition(uint8_t x, uint8_t y, int16_t rotation);
```

Updates the widget’s center point. The optional `rotation` overrides current rotation (degrees, −180 to +180).

---

### `setSize()`

```cpp
void setSize(uint8_t size);
void setSize(uint8_t size, float aspectRatio);
```

- `setSize(size)` — changes height; preserves current aspect ratio.
- `setSize(size, aspectRatio)` — changes both. The float is converted to wire format internally.

---

### `setAspectRatio()`

```cpp
void setAspectRatio(float aspectRatio);
```

Changes aspect ratio without touching size. Pass `0` to revert to the widget’s built-in default.

---

### `show()` / `hide()`

```cpp
void show();
void hide();
```

Controls visibility. Hidden widgets still send and receive data normally.

---

## 4. Widget Class Reference

All constructors follow the same signature:

```cpp
WidgetType("label", x, y, size, aspectRatio = 0);  // label-first
WidgetType(x, y, size, aspectRatio = 0);           // no-label
```

- **label** — optional, max 32 chars
- **x, y** — center position (0–200)
- **size** — height in canvas units (0–200)
- **aspectRatio** — `float`; `0` = widget default. Stored as `uint8_t` (×10).

---

### `RadioKit_Button`

Momentary push button. Sends `1` while held, `0` when released.

**Default aspect:** `2.5` (wire: `25`)

| Method | Returns | Description |
|---|---|---|
| `isPressed()` | `bool` | `true` once on leading edge; auto-clears on read |
| `isHeld()` | `bool` | `true` continuously while held |

```cpp
RadioKit_Button fire("Fire", 20, 50, 20);       // default aspect 2.5
RadioKit_Button fire("Fire", 20, 50, 20, 1.0);  // square
```

---

### `RadioKit_Switch`

Toggle switch. Stays ON or OFF between interactions.

**Default aspect:** `1.6` (wire: `16`)

| Method | Returns | Description |
|---|---|---|
| `isOn()` | `bool` | `true` = switch is ON |

```cpp
RadioKit_Switch light("Light", 60, 50, 16);
digitalWrite(RELAY_PIN, light.isOn() ? HIGH : LOW);
```

---

### `RadioKit_Slider`

Linear slider. Returns `0`–`100`.

**Default aspect:** `5.0` (wire: `50`)

| Method | Returns | Description |
|---|---|---|
| `value()` | `uint8_t` | Current position 0–100 |

```cpp
RadioKit_Slider speed("Speed", 100, 20, 10);
analogWrite(PWM_PIN, map(speed.value(), 0, 100, 0, 255));
```

---

### `RadioKit_Joystick`

2-axis joystick.

**Default aspect:** `1.0` (wire: `10`) — always square

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

Color indicator. Write-only (Arduino → App).

**Default aspect:** `1.0` (wire: `10`) — circular

| Method | Description |
|---|---|
| `set(color)` | Set color: `RadioKit_LED::OFF/RED/GREEN/BLUE/YELLOW` |
| `get()` | Returns current `RadioKit_LEDColor` |

```cpp
RadioKit_LED status(20, 20, 15);
status.set(RadioKit_LED::GREEN);
```

---

### `RadioKit_Text`

Text display panel. Write-only (Arduino → App).

**Default aspect:** `4.0` (wire: `40`)

| Method | Description |
|---|---|
| `set(const char*)` | Update displayed string (max 31 chars + null) |
| `set(const String&)` | Arduino `String` overload |
| `get()` | Returns `const char*` |

```cpp
RadioKit_Text sensor("Sensor", 100, 80, 15);
char buf[32];
snprintf(buf, 32, "A0=%d", analogRead(A0));
sensor.set(buf);
```

---

## 5. RadioKit (Main Object)

`RadioKit` is a global singleton. Use `RadioKit.method()` directly.

### `startBLE()`

```cpp
void RadioKit.startBLE(const char* deviceName, const char* password = nullptr);
```

Initialises BLE and starts advertising. Call once at the end of `setup()`.

### `update()`

```cpp
void RadioKit.update();
```

Processes BLE events. **Must be called once every `loop()` iteration.**

### `isConnected()`

```cpp
bool RadioKit.isConnected() const;
```

Returns `true` if a RadioKit app is currently connected.

---

## 6. Coordinate System

```
(0,200) ┌──────────────────────────┐ (200,200)
        │  Y increases ↑          │
        │  X increases →          │
  (0,0) └──────────────────────────┘ (200,0)
```

- Origin `(0,0)` = bottom-left
- `x`, `y` = **center** of the widget
- Canvas range: 0–200 on both axes

---

## 7. Constants & Enums

```cpp
enum RadioKit_Orientation : uint8_t {
    RK_LANDSCAPE = 0x00,
    RK_PORTRAIT  = 0x01
};

enum RadioKit_LEDColor : uint8_t {
    RK_LED_OFF = 0, RK_LED_RED, RK_LED_GREEN, RK_LED_BLUE, RK_LED_YELLOW
};

#define RADIOKIT_MAX_WIDGETS  16
#define RADIOKIT_MAX_LABEL    32
#define RADIOKIT_TEXT_LEN     32
```

---

## 8. Full Sketch Example

```cpp
#include <RadioKit.h>

RadioKit_Joystick drive ("Drive",  160, 50, 35);   // 35h × 35w  (aspect 1.0)
RadioKit_Slider   speed ("Speed",  100, 15, 10);   // 10h × 50w  (aspect 5.0)
RadioKit_Switch   light ("Light",   60, 50, 16);   // 16h × 26w  (aspect 1.6)
RadioKit_Button   honk  ("Honk",    20, 50, 20);   // 20h × 50w  (aspect 2.5)
RadioKit_LED      status(           20, 20, 12);   // circle d=12
RadioKit_Text     sensor("Sensor", 100, 80, 12);   // 12h × 48w  (aspect 4.0)

void setup() {
    RadioKit.startBLE("RoboCar");
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
