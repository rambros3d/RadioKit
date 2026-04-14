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
   - [startBLE()](#startble)
   - [startSerial()](#startserial)
   - [update()](#update)
   - [isConnected()](#isconnected)
6. [Coordinate System](#6-coordinate-system)
7. [Constants & Enums](#7-constants--enums)
8. [Full Sketch Example](#8-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a simple three-part pattern. Widgets **register themselves automatically** on declaration.

```cpp
#include <RadioKit.h>

// ── Part 1: Widget declarations ──────────────────────────────────────────
RadioKit_Button  fireBtn("Fire", 20, 50, 20);
RadioKit_LED     status (        20, 20, 12);

// ── Part 2: setup() ────────────────────────────────────────────────────
void setup() {
    RadioKit.startBLE("MyDevice");       // BLE mode
    // RadioKit.startSerial(Serial);     // — or — USB Serial mode
}

// ── Part 3: loop() ────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
    if (fireBtn.isPressed()) status.set(RadioKit_LED::GREEN);
}
```

> Switching between BLE and Serial requires changing only the one `startXxx()` call. All widget code is identical.

---

## 2. Layout Model — Size & Aspect Ratio

RadioKit uses a **Size + Aspect Ratio** model. The Arduino transmits both values; the **app computes the final dimensions**.

### Definitions

```
height = size
width  = size × (aspect / 10.0)     // computed by the app
```

### Wire Encoding

Aspect ratio is transmitted as a `uint8_t` with **×10 scale** (range 0.0–25.5):

| Float ratio | Wire value |
|---|---|
| 1.0 | 10 |
| 1.6 | 16 |
| 2.5 | 25 |
| 4.0 | 40 |
| 5.0 | 50 |
| 25.5 | 255 (max) |

### Aspect Ratio = 0 (Auto)

`0` in the constructor selects the widget’s built-in default:

| Widget | Default ratio | Wire value |
|---|---|---|
| `RadioKit_Button` | 2.5 | 25 |
| `RadioKit_Switch` | 1.6 | 16 |
| `RadioKit_Slider` | 5.0 | 50 |
| `RadioKit_Joystick` | 1.0 | 10 |
| `RadioKit_LED` | 1.0 | 10 |
| `RadioKit_Text` | 4.0 | 40 |

`0` is resolved to the widget’s default before transmission — the app never receives `0`.

### Worked Example

```
RadioKit_Joystick joy(160, 50, 40);       // aspect=0 → wire 10
// App: h=40, w=40×(10÷10)=40  (square)

RadioKit_Slider   spd(100, 20, 10, 8.0); // aspect=8.0 → wire 80
// App: h=10, w=10×(80÷10)=80  (long bar)
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
void setSize(uint8_t size);
void setSize(uint8_t size, float aspectRatio);
```
`setSize(size)` preserves current aspect. `setSize(size, ratio)` updates both.

### `setAspectRatio()`
```cpp
void setAspectRatio(float aspectRatio);  // 0 = revert to widget default
```

### `show()` / `hide()`
```cpp
void show();
void hide();
```

---

## 4. Widget Class Reference

All constructors:
```cpp
WidgetType("label", x, y, size, aspectRatio = 0);
WidgetType(x, y, size, aspectRatio = 0);
```

---

### `RadioKit_Button`
**Default aspect:** 2.5 (wire: 25)

| Method | Returns | Description |
|---|---|---|
| `isPressed()` | `bool` | `true` once on leading edge; auto-clears |
| `isHeld()` | `bool` | `true` while held |

```cpp
RadioKit_Button fire("Fire", 20, 50, 20);
if (fire.isPressed()) trigger();
```

---

### `RadioKit_Switch`
**Default aspect:** 1.6 (wire: 16)

| Method | Returns | Description |
|---|---|---|
| `isOn()` | `bool` | `true` = switch is ON |

```cpp
RadioKit_Switch light("Light", 60, 50, 16);
digitalWrite(RELAY, light.isOn() ? HIGH : LOW);
```

---

### `RadioKit_Slider`
**Default aspect:** 5.0 (wire: 50)

| Method | Returns | Description |
|---|---|---|
| `value()` | `uint8_t` | Position 0–100 |

```cpp
RadioKit_Slider speed("Speed", 100, 20, 10);
analogWrite(PWM, map(speed.value(), 0, 100, 0, 255));
```

---

### `RadioKit_Joystick`
**Default aspect:** 1.0 (wire: 10) — always square

| Method | Returns | Description |
|---|---|---|
| `getX()` | `int8_t` | −100..+100 |
| `getY()` | `int8_t` | −100..+100 |

```cpp
RadioKit_Joystick drive("Drive", 160, 50, 35);
```

---

### `RadioKit_LED`
**Default aspect:** 1.0 (wire: 10) — circular

| Method | Description |
|---|---|
| `set(color)` | `RadioKit_LED::OFF/RED/GREEN/BLUE/YELLOW` |
| `get()` | Returns current `RadioKit_LEDColor` |

```cpp
RadioKit_LED status(20, 20, 15);
status.set(RadioKit_LED::GREEN);
```

---

### `RadioKit_Text`
**Default aspect:** 4.0 (wire: 40)

| Method | Description |
|---|---|
| `set(const char*)` | Update text (max 31 chars + null) |
| `set(const String&)` | Arduino String overload |
| `get()` | Returns `const char*` |

```cpp
RadioKit_Text sensor("Sensor", 100, 80, 15);
sensor.set("Hello");
```

---

## 5. RadioKit (Main Object)

`RadioKit` is a global singleton.

### `startBLE()`
```cpp
void RadioKit.startBLE(const char* deviceName, const char* password = nullptr);
```
Initialises NimBLE and starts advertising. Call once at end of `setup()`.

---

### `startSerial()`
```cpp
void RadioKit.startSerial(Stream& stream, uint32_t baud = 115200);
```
Initialises the USB Serial transport.

| Parameter | Description |
|---|---|
| `stream` | Any Arduino `Stream`: `Serial`, `Serial1`, `SoftwareSerial`, … |
| `baud` | Baud rate. Pass `0` if the stream is already initialised. |

`isConnected()` returns `true` for **3 seconds** after the last valid packet. The app must send `PING` at least every 2 s to maintain the session.

**Example:**
```cpp
// USB (Chrome Web Serial / Android)
RadioKit.startSerial(Serial);

// Hardware UART at custom baud
RadioKit.startSerial(Serial1, 9600);

// Pre-initialised stream (pass baud=0)
Serial.begin(115200);
RadioKit.startSerial(Serial, 0);
```

---

### `update()`
```cpp
void RadioKit.update();
```
Polls the active transport. **Call once every `loop()` iteration.**

---

### `isConnected()`
```cpp
bool RadioKit.isConnected() const;
```
- **BLE:** `true` while a peer is connected.
- **Serial:** `true` for 3 s after the last valid packet. `false` at boot until first packet.

---

## 6. Coordinate System

```
(0,200) ┌──────────────────────────┐ (200,200)
        │  Y increases ↑          │
        │  X increases →          │
  (0,0) └──────────────────────────┘ (200,0)
```
Origin = bottom-left. `x`,`y` = widget center.

---

## 7. Constants & Enums

```cpp
enum RadioKit_Orientation : uint8_t { RK_LANDSCAPE = 0x00, RK_PORTRAIT = 0x01 };

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

RadioKit_Joystick drive ("Drive",  160, 50, 35);
RadioKit_Slider   speed ("Speed",  100, 15, 10);
RadioKit_Switch   light ("Light",   60, 50, 16);
RadioKit_Button   honk  ("Honk",    20, 50, 20);
RadioKit_LED      status(           20, 20, 12);
RadioKit_Text     sensor("Sensor", 100, 80, 12);

void setup() {
    RadioKit.startBLE("RoboCar");       // swap for startSerial(Serial) to test over USB
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
