# RadioKit Library — Function Reference

> **Note:** This document reflects the **planned v2.0 API** using the struct sync architecture. All items marked ⚠️ *pending implementation* are not yet in the codebase.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [Config Block Macros](#2-config-block-macros)
3. [Struct Field Types](#3-struct-field-types)
4. [RadioKit (Main Object)](#4-radiokit-main-object)
   - [begin()](#begin)
   - [handle()](#handle)
   - [isConnected()](#isconnected)
5. [LED Color Constants](#5-led-color-constants)
6. [Constants & Enums](#6-constants--enums)
7. [Coordinate System](#7-coordinate-system)
8. [Edge Detection Helper](#8-edge-detection-helper)
9. [Full Sketch Example](#9-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows this four-part pattern:

```cpp
#include <RadioKit.h>

// ── Part 1: Config block — widget layout ──────────────────────────────────
RK_CONFIG_BEGIN(RK_LANDSCAPE)
    RK_BUTTON  (20,  50, 25, 20, 0,  "Fire")
    RK_LED     (20,  20, 12, 12, 0,  "Status")
RK_CONFIG_END

// ── Part 2: Flat struct — one field per widget value ─────────────────────
struct {
    uint8_t fire;         // Button input
    uint8_t statusLed;    // LED output
    uint8_t connect_flag; // 1 = connected, 0 = disconnected (set by library)
} rk;

// ── Part 3: setup() ──────────────────────────────────────────────────────
void setup() {
    RadioKit.begin("MyDevice", &rk);
}

// ── Part 4: loop() ───────────────────────────────────────────────────────
void loop() {
    RadioKit.handle();
    if (rk.fire) rk.statusLed = RK_LED_GREEN;
}
```

> **Struct field order rule:** Input widget fields first (in config order), then output widget fields (in config order), then `connect_flag` last.

---

## 2. Config Block Macros

⚠️ *pending implementation*

The config block defines the UI layout. It compiles to a `PROGMEM` byte array that is sent to the app as the `CONF_DATA` packet.

### `RK_CONFIG_BEGIN(orientation)`

Opens the config block and sets the canvas orientation.

| Parameter | Values | Description |
|---|---|---|
| `orientation` | `RK_LANDSCAPE` / `RK_PORTRAIT` | Canvas orientation |

### `RK_CONFIG_END`

Closes the config block. Must follow `RK_CONFIG_BEGIN`.

### Widget Macros

All widget macros share the same parameter signature:

```cpp
RK_WIDGET_TYPE(x, y, w, h, rotation, "Label")
```

| Parameter | Type | Description |
|---|---|---|
| `x` | `uint8_t` | Center X on virtual canvas |
| `y` | `uint8_t` | Center Y on virtual canvas |
| `w` | `uint8_t` | Widget width |
| `h` | `uint8_t` | Widget height |
| `rotation` | `int16_t` | Rotation in degrees `-180` to `+180` (default `0`) |
| `"Label"` | string literal | Display label (max 32 chars) |

| Macro | Widget type | Direction |
|---|---|---|
| `RK_BUTTON(x,y,w,h,rot,label)` | Momentary button | App → Arduino |
| `RK_SWITCH(x,y,w,h,rot,label)` | Toggle switch | App → Arduino |
| `RK_SLIDER(x,y,w,h,rot,label)` | Linear slider | App → Arduino |
| `RK_JOYSTICK(x,y,w,h,rot,label)` | 2-axis joystick | App → Arduino |
| `RK_LED(x,y,w,h,rot,label)` | LED indicator | Arduino → App |
| `RK_TEXT(x,y,w,h,rot,label)` | Text display | Arduino → App |

**Example:**
```cpp
RK_CONFIG_BEGIN(RK_LANDSCAPE)
    RK_BUTTON  (20,  50, 25, 20,  0,  "Fire")
    RK_JOYSTICK(160, 50, 35, 35,  0,  "Drive")
    RK_SLIDER  (100, 15, 60, 12, 90,  "Throttle")  // rotated 90°
    RK_LED     (20,  20, 12, 12,  0,  "Status")
    RK_TEXT    (100, 80, 70, 15,  0,  "Sensor")
RK_CONFIG_END
```

---

## 3. Struct Field Types

Declare your struct fields in the **same order** as the config macros, inputs before outputs.

| Config macro | Input field(s) in struct | Type(s) | Value range |
|---|---|---|---|
| `RK_BUTTON` | `uint8_t name` | `uint8_t` | `1` = pressed, `0` = released |
| `RK_SWITCH` | `uint8_t name` | `uint8_t` | `1` = on, `0` = off |
| `RK_SLIDER` | `uint8_t name` | `uint8_t` | `0`–`100` |
| `RK_JOYSTICK` | `int8_t nameX, nameY` | `int8_t`, `int8_t` | `-100`–`+100` each |
| `RK_LED` | *(output only)* `uint8_t name` | `uint8_t` | `0`–`4` (use `RK_LED_*` constants) |
| `RK_TEXT` | *(output only)* `char name[32]` | `char[32]` | null-terminated string |

**Example struct matching the config above:**
```cpp
struct {
    // inputs — in config order
    uint8_t fire;       // RK_BUTTON
    int8_t  driveX;     // RK_JOYSTICK X
    int8_t  driveY;     // RK_JOYSTICK Y
    uint8_t throttle;   // RK_SLIDER
    // outputs — in config order
    uint8_t statusLed;       // RK_LED
    char    sensorText[32];  // RK_TEXT
    // meta
    uint8_t connect_flag;
} rk;
```

---

## 4. RadioKit (Main Object)

`RadioKit` is a global singleton. Never instantiate it — use `RadioKit.method()` directly.

---

### `begin()`

```cpp
void RadioKit.begin(const char* deviceName, void* structPtr);
```

Initialises BLE, links the config array to the struct pointer, and starts advertising. Call once at the end of `setup()`.

| Parameter | Type | Description |
|---|---|---|
| `deviceName` | `const char*` | BLE device name visible during scanning |
| `structPtr` | `void*` | Pointer to your flat control struct (e.g. `&rk`) |

**Example:**
```cpp
RadioKit.begin("CoolBot", &rk);
```

---

### `handle()`

```cpp
void RadioKit.handle();
```

Processes BLE events and protocol messages. **Must be called once every `loop()` iteration.** Internally handles `GET_CONF`, `GET_VARS`, `SET_INPUT`, `PING`, and `connect_flag` updates.

**Example:**
```cpp
void loop() {
    RadioKit.handle();
    // your code here
}
```

---

### `isConnected()`

```cpp
bool RadioKit.isConnected() const;
```

Returns `true` if a RadioKit app is currently connected. Equivalent to checking `rk.connect_flag == 1`.

**Example:**
```cpp
if (!RadioKit.isConnected()) {
    rk.statusLed = RK_LED_OFF;
}
```

---

## 5. LED Color Constants

Use these constants to set an `RK_LED` output field in your struct:

```cpp
#define RK_LED_OFF    0
#define RK_LED_RED    1
#define RK_LED_GREEN  2
#define RK_LED_BLUE   3
#define RK_LED_YELLOW 4
```

**Example:**
```cpp
rk.statusLed = RK_LED_GREEN;
rk.statusLed = RK_LED_OFF;
```

---

## 6. Constants & Enums

### Orientation ⚠️ *pending implementation*

```cpp
enum RadioKit_Orientation : uint8_t {
    RK_LANDSCAPE = 0x00,   // Canvas: 200 wide × 100 tall
    RK_PORTRAIT  = 0x01    // Canvas: 100 wide × 200 tall
};
```

### Canvas Dimensions ⚠️ *pending implementation*

```cpp
#define RK_CANVAS_LANDSCAPE_W  200
#define RK_CANVAS_LANDSCAPE_H  100
#define RK_CANVAS_PORTRAIT_W   100
#define RK_CANVAS_PORTRAIT_H   200
```

### Limits

```cpp
#define RADIOKIT_MAX_WIDGETS  16   // max widgets per sketch
#define RADIOKIT_MAX_LABEL    32   // max label length (chars)
#define RADIOKIT_TEXT_LEN     32   // max RK_TEXT string length
```

### Widget Type IDs (internal — protocol reference)

```cpp
#define RK_TYPE_BUTTON   0x01
#define RK_TYPE_SWITCH   0x02
#define RK_TYPE_SLIDER   0x03
#define RK_TYPE_JOYSTICK 0x04
#define RK_TYPE_LED      0x05
#define RK_TYPE_TEXT     0x06
```

---

## 7. Coordinate System

### Origin & Axes

```
(0, canvasH)  ┌──────────────────────┐  (canvasW, canvasH)
              │                      │
              │    Y increases ↑     │
              │                      │
              │    X increases →     │
              │                      │
       (0, 0) └──────────────────────┘  (canvasW, 0)
              bottom-left is origin
```

- **`(0, 0)`** = bottom-left corner
- **X** increases left → right
- **Y** increases bottom → top

### Widget Position

`x` and `y` in the config macro refer to the **center** of the widget:

```
        ┌──────────┐
        │          │  H
        │  (x, y)  │
        │  center  │
        └──────────┘
             W
```

### Rotation ⚠️ *pending implementation*

- Macro parameter: `-180` to `+180` degrees
- Wire storage: `int8_t` from `-90` to `+90` (÷2 on store, ×2 to recover)
- Positive = counter-clockwise
- Default = `0`

---

## 8. Edge Detection Helper

⚠️ *pending implementation*

The struct sync approach gives you a raw `uint8_t` for buttons (1 = held, 0 = released). For one-shot trigger behaviour (equivalent to the old `pressed()`), use the `RK_RISING` macro:

```cpp
// Declare a previous-state variable for each button you want edge detection on
uint8_t prev_fire = 0;

void loop() {
    RadioKit.handle();

    if (RK_RISING(rk.fire, prev_fire)) {
        // Fires exactly once per press, on the leading edge
        triggerAction();
    }
}
```

`RK_RISING(current, prev)` expands to:
```cpp
(((current) && !(prev)) ? ((prev) = (current), true) : ((prev) = (current), false))
```

---

## 9. Full Sketch Example

```cpp
#include <RadioKit.h>

// ── Config ────────────────────────────────────────────────────────────────
RK_CONFIG_BEGIN(RK_LANDSCAPE)
    RK_BUTTON  (20,  50, 25, 20, 0, "Fire")
    RK_SWITCH  (60,  50, 25, 15, 0, "Light")
    RK_SLIDER  (100, 15, 60, 12, 0, "Speed")
    RK_JOYSTICK(160, 50, 35, 35, 0, "Drive")
    RK_LED     (20,  20, 12, 12, 0, "Status")
    RK_TEXT    (100, 80, 70, 15, 0, "Sensor")
RK_CONFIG_END

// ── Struct ────────────────────────────────────────────────────────────────
struct {
    // inputs
    uint8_t fire;
    uint8_t light;
    uint8_t speed;
    int8_t  driveX;
    int8_t  driveY;
    // outputs
    uint8_t statusLed;
    char    sensorText[32];
    // meta
    uint8_t connect_flag;
} rk;

// Edge detection state
uint8_t prev_fire = 0;

void setup() {
    pinMode(RELAY_PIN, OUTPUT);
    RadioKit.begin("DemoBot", &rk);
}

void loop() {
    RadioKit.handle();

    // One-shot fire trigger
    if (RK_RISING(rk.fire, prev_fire)) {
        rk.statusLed = RK_LED_RED;
    }

    // Toggle relay with switch
    digitalWrite(RELAY_PIN, rk.light ? HIGH : LOW);

    // Motor speed from slider
    analogWrite(MOTOR_PIN, map(rk.speed, 0, 100, 0, 255));

    // Differential drive from joystick
    int left  = constrain(rk.driveY + rk.driveX, -100, 100);
    int right = constrain(rk.driveY - rk.driveX, -100, 100);
    analogWrite(LEFT_MOTOR,  map(left,  -100, 100, 0, 255));
    analogWrite(RIGHT_MOTOR, map(right, -100, 100, 0, 255));

    // Push sensor reading to app
    snprintf(rk.sensorText, 32, "A0=%d", analogRead(A0));

    // Clear LED when disconnected
    if (!RadioKit.isConnected()) {
        rk.statusLed = RK_LED_OFF;
    }
}
```
