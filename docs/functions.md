# RadioKit Library — Function Reference

> **Note:** This document reflects the **planned v2.0 Object-Oriented API** including the **Size & Aspect Ratio** layout model. Items marked ⚠️ *pending implementation* are not yet in the codebase.

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
   - [update()](#update)
   - [isConnected()](#isconnected)
6. [Coordinate System](#6-coordinate-system)
7. [Constants & Enums](#7-constants--enums)
8. [Full Sketch Example](#8-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows this simple three-part pattern. Widgets **register themselves automatically** upon declaration — no `addWidget()` call needed.

```cpp
#include <RadioKit.h>

// ── Part 1: Widget declarations ──────────────────────────────────────────
// Format: ["Label",] x, y, size [, aspectRatio]
// size   = Height in canvas units (0–200)
// aspect = Width / Height ratio. 0 = use this widget's built-in default.
RadioKit_Button  fireBtn("Fire",   20,  50, 20);
RadioKit_LED     status (           20,  20, 12);

// ── Part 2: setup() ──────────────────────────────────────────────────────
void setup() {
    RadioKit.startBLE("MyDevice");
}

// ── Part 3: loop() ───────────────────────────────────────────────────────
void loop() {
    RadioKit.update();

    if (fireBtn.isPressed()) {
        status.set(RadioKit_LED::GREEN);
    }
}
```

---

## 2. Layout Model — Size & Aspect Ratio

RadioKit uses a **Size + Aspect Ratio** layout model instead of explicit Width and Height.

### Definitions

```
Height = size
Width  = size × aspectRatio
```

`size` maps directly to the **height** of the widget. `aspectRatio` stretches or squeezes the width relative to that height.

### Aspect Ratio = 0 (Auto)

Passing `0` (the default) tells the library to use the widget's **built-in default ratio**. Each widget type defines its own sensible default:

| Widget | Default Aspect | Resulting shape |
|---|---|---|
| `RadioKit_Button` | `2.5` | Wide landscape button |
| `RadioKit_Switch` | `1.6` | Rounded toggle |
| `RadioKit_Slider` | `5.0` | Thin horizontal bar |
| `RadioKit_Joystick` | `1.0` | Square |
| `RadioKit_LED` | `1.0` | Circle |
| `RadioKit_Text` | `4.0` | Wide text banner |

### Worked Example

```
RadioKit_Joystick joy(160, 50, 40);        // size=40, aspect=0 → default 1.0
// → Height = 40,  Width = 40 × 1.0 = 40  (square)

RadioKit_Slider   spd(100, 20, 10, 8.0);  // size=10, aspect=8.0
// → Height = 10,  Width = 10 × 8.0 = 80  (long thin bar)

RadioKit_Button   btn(20,  50, 18, 3.0);  // size=18, aspect=3.0
// → Height = 18,  Width = 18 × 3.0 = 54  (very wide)
```

### Protocol Layer

On the wire the library converts back to explicit W and H before serializing into `CONF_DATA`:

```
W = (uint8_t)(size × aspectRatio)   // uses default if aspectRatio == 0
H = size
```

Both values are clamped to `uint8_t` (max 255).

---

## 3. Common Widget Methods

All widgets inherit these methods. They can be called at any time — changes are reflected the next time the app requests `CONF_DATA` or `VAR_DATA`.

### `setPosition()`

```cpp
void setPosition(uint8_t x, uint8_t y);
void setPosition(uint8_t x, uint8_t y, int16_t rotation);
```

Updates the widget's **center point** on the virtual canvas. The optional `rotation` overrides the current rotation (degrees, `−180` to `+180`).

**Example:**
```cpp
fireBtn.setPosition(40, 60);          // move only
fireBtn.setPosition(40, 60, 45);      // move and rotate 45°
```

---

### `setSize()`

```cpp
void setSize(uint8_t size);
void setSize(uint8_t size, float aspectRatio);
```

Updates the widget's scale.

- `setSize(size)` — changes height only; preserves current aspect ratio (or default if none set).
- `setSize(size, aspectRatio)` — changes both height and aspect ratio together.

> **Removed:** `setSize(width, height)` (explicit W/H form) is no longer part of the API. Use `setSize(size, aspectRatio)` instead.

**Example:**
```cpp
joy.setSize(40);             // keep current aspect, change height to 40
slider.setSize(12, 6.0);     // height 12, width = 12 × 6.0 = 72
```

---

### `setAspectRatio()`

```cpp
void setAspectRatio(float aspectRatio);
```

Changes the aspect ratio without touching the current size. Pass `0` to revert to the widget's built-in default.

**Example:**
```cpp
btn.setAspectRatio(1.0);    // make button square
btn.setAspectRatio(0);      // revert to default 2.5
```

---

### `show()` / `hide()` ⚠️ *pending implementation*

```cpp
void show();
void hide();
```

Controls whether the widget is rendered in the app. Hidden widgets still send and receive data normally.

---

## 4. Widget Class Reference

All constructors follow the same signature pattern:

```cpp
WidgetType("label", x, y, size, aspectRatio = 0);  // label-first form
WidgetType(x, y, size, aspectRatio = 0);           // no-label form
```

- **Label** — optional, comes first if provided (max 32 chars)
- **x, y** — center position on the virtual canvas (`uint8_t`, 0–200)
- **size** — height of the widget (`uint8_t`, 0–200)
- **aspectRatio** — width/height ratio (`float`); `0` = use widget default

---

### `RadioKit_Button`

A momentary push button. Sends `1` while held, `0` when released.

**Constructors:**
```cpp
RadioKit_Button(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_Button(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `2.5` → a `size=20` button is `20 × 50` units

| Method | Returns | Description |
|---|---|---|
| `isPressed()` | `bool` | `true` **once** on the leading edge of a press (auto-clears on read) |
| `isHeld()` | `bool` | `true` continuously while the button is held down |

**Example:**
```cpp
RadioKit_Button fire("Fire", 20, 50, 20);      // 20 tall × 50 wide (default aspect 2.5)
RadioKit_Button fire("Fire", 20, 50, 20, 1.0); // 20 × 20 (square)

if (fire.isPressed()) triggerOnce();
if (fire.isHeld())    continuousThrust();
```

---

### `RadioKit_Switch`

A toggle switch. Stays ON or OFF between interactions.

**Constructors:**
```cpp
RadioKit_Switch(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_Switch(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `1.6` → a `size=16` switch is `16 × 26` units

| Method | Returns | Description |
|---|---|---|
| `isOn()` | `bool` | `true` = switch is ON, `false` = switch is OFF |

**Example:**
```cpp
RadioKit_Switch light("Light", 60, 50, 16);

digitalWrite(RELAY_PIN, light.isOn() ? HIGH : LOW);
```

---

### `RadioKit_Slider`

A linear slider returning a value from `0` to `100`.

**Constructors:**
```cpp
RadioKit_Slider(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_Slider(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `5.0` → a `size=12` slider is `12 × 60` units (thin horizontal bar)

| Method | Returns | Description |
|---|---|---|
| `value()` | `uint8_t` | Current position `0`–`100` |

**Example:**
```cpp
RadioKit_Slider speed("Speed", 100, 20, 10);       // 10 tall × 50 wide (default)
RadioKit_Slider speed("Speed", 100, 20, 10, 8.0);  // 10 tall × 80 wide

analogWrite(PWM_PIN, map(speed.value(), 0, 100, 0, 255));
```

---

### `RadioKit_Joystick`

A 2-axis joystick. Reports independent X and Y axes.

**Constructors:**
```cpp
RadioKit_Joystick(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_Joystick(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `1.0` → always square (a `size=35` joystick is `35 × 35` units)

| Method | Returns | Description |
|---|---|---|
| `getX()` | `int8_t` | Horizontal axis: `−100` (full left) to `+100` (full right), `0` = center |
| `getY()` | `int8_t` | Vertical axis: `−100` (full down) to `+100` (full up), `0` = center |

**Example:**
```cpp
RadioKit_Joystick drive("Drive", 160, 50, 35);

int left  = constrain(drive.getY() + drive.getX(), -100, 100);
int right = constrain(drive.getY() - drive.getX(), -100, 100);
```

---

### `RadioKit_LED`

An LED color indicator. Write-only (Arduino → App).

**Constructors:**
```cpp
RadioKit_LED(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_LED(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `1.0` → always circular (size = diameter in canvas units)

| Method | Description |
|---|---|
| `set(color)` | Set LED color using `RadioKit_LED::OFF/RED/GREEN/BLUE/YELLOW` |
| `get()` | Returns current `RadioKit_LEDColor` |

**Color constants:**

```cpp
RadioKit_LED::OFF
RadioKit_LED::RED
RadioKit_LED::GREEN
RadioKit_LED::BLUE
RadioKit_LED::YELLOW
```

**Example:**
```cpp
RadioKit_LED status(20, 20, 15);           // circle, diameter 15
RadioKit_LED status(20, 20, 10, 2.0);      // ellipse, 10 tall × 20 wide

status.set(RadioKit_LED::GREEN);
status.set(RadioKit_LED::OFF);
```

---

### `RadioKit_Text`

A text display panel. Write-only (Arduino → App).

**Constructors:**
```cpp
RadioKit_Text(const char* label, uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
RadioKit_Text(uint8_t x, uint8_t y, uint8_t size, float aspect = 0);
```

**Default Aspect:** `4.0` → a `size=15` text widget is `15 × 60` units

| Method | Description |
|---|---|
| `set(const char*)` | Update the displayed string (max 32 chars, null-terminated) |
| `set(const String&)` | Arduino `String` overload |
| `get()` | Returns current `const char*` |

**Example:**
```cpp
RadioKit_Text sensor("Sensor", 100, 80, 15);

snprintf(buf, 32, "A0=%d", analogRead(A0));
sensor.set(buf);
```

---

## 5. RadioKit (Main Object)

`RadioKit` is a global singleton. Never instantiate it — use `RadioKit.method()` directly.

---

### `startBLE()`

```cpp
void RadioKit.startBLE(const char* deviceName, const char* password = nullptr);
```

Initialises BLE and starts advertising. Call once at the end of `setup()`. All widget declarations must appear before this call.

| Parameter | Type | Description |
|---|---|---|
| `deviceName` | `const char*` | BLE name visible during scanning |
| `password` | `const char*` | Optional connection password. `nullptr` = open (default) |

**Example:**
```cpp
RadioKit.startBLE("MyCar");
RadioKit.startBLE("MyCar", "1234");  // password-protected
```

---

### `update()`

```cpp
void RadioKit.update();
```

Processes BLE events and protocol messages. **Must be called once every `loop()` iteration.**

**Example:**
```cpp
void loop() {
    RadioKit.update();
    // your code
}
```

---

### `isConnected()`

```cpp
bool RadioKit.isConnected() const;
```

Returns `true` if a RadioKit app is currently connected.

**Example:**
```cpp
if (!RadioKit.isConnected()) {
    status.set(RadioKit_LED::OFF);
}
```

---

## 6. Coordinate System

```
(0, 200)  ┌──────────────────────────┐  (200, 200)
          │                          │
          │    Y increases ↑         │
          │    X increases →         │
          │                          │
   (0, 0) └──────────────────────────┘  (200, 0)
          bottom-left is origin
```

- **Origin `(0, 0)`** = bottom-left corner
- **X** increases left → right (0–200)
- **Y** increases bottom → top (0–200)
- **`x`, `y`** in constructors refer to the **center** of the widget
- Canvas max is **200** in both axes (orientation sets which axis maps to width/height)

---

## 7. Constants & Enums

### Orientation

```cpp
enum RadioKit_Orientation : uint8_t {
    RK_LANDSCAPE = 0x00,   // default
    RK_PORTRAIT  = 0x01
};
```

### Widget Limits

```cpp
#define RADIOKIT_MAX_WIDGETS  16
#define RADIOKIT_MAX_LABEL    32
#define RADIOKIT_TEXT_LEN     32
```

### LED Colors

```cpp
RadioKit_LED::OFF
RadioKit_LED::RED
RadioKit_LED::GREEN
RadioKit_LED::BLUE
RadioKit_LED::YELLOW
```

---

## 8. Full Sketch Example

A robot car controlled by a joystick, with a speed slider, a light switch, and sensor feedback:

```cpp
#include <RadioKit.h>

// ── Widgets ───────────────────────────────────────────────────────────────
RadioKit_Joystick drive ("Drive",  160, 50, 35);      // 35×35 square (aspect 1.0)
RadioKit_Slider   speed ("Speed",  100, 15, 10);      // 10 tall × 50 wide (aspect 5.0)
RadioKit_Switch   light ("Light",   60, 50, 16);      // 16 tall × 26 wide (aspect 1.6)
RadioKit_Button   honk  ("Honk",    20, 50, 20);      // 20 tall × 50 wide (aspect 2.5)
RadioKit_LED      status(           20, 20, 12);      // circle, diameter 12
RadioKit_Text     sensor("Sensor", 100, 80, 12);      // 12 tall × 48 wide (aspect 4.0)

void setup() {
    pinMode(RELAY_PIN,    OUTPUT);
    pinMode(HORN_PIN,     OUTPUT);
    RadioKit.startBLE("RoboCar");
}

void loop() {
    RadioKit.update();

    if (!RadioKit.isConnected()) {
        status.set(RadioKit_LED::OFF);
        return;
    }

    // Differential drive
    int spd   = speed.value();                          // 0–100
    int left  = constrain(drive.getY() + drive.getX(), -100, 100);
    int right = constrain(drive.getY() - drive.getX(), -100, 100);
    analogWrite(LEFT_MOTOR,  map(left  * spd / 100, -100, 100, 0, 255));
    analogWrite(RIGHT_MOTOR, map(right * spd / 100, -100, 100, 0, 255));

    // Relay and horn
    digitalWrite(RELAY_PIN, light.isOn() ? HIGH : LOW);
    digitalWrite(HORN_PIN,  honk.isHeld() ? HIGH : LOW);

    // Status LED
    if      (abs(drive.getX()) > 50 || abs(drive.getY()) > 50)
        status.set(RadioKit_LED::GREEN);
    else if (light.isOn())
        status.set(RadioKit_LED::YELLOW);
    else
        status.set(RadioKit_LED::BLUE);

    // Sensor readout
    char buf[32];
    snprintf(buf, 32, "A0=%d  A1=%d", analogRead(A0), analogRead(A1));
    sensor.set(buf);
}
```
