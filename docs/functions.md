# RadioKit Library — Function Reference

> **Note:** This document reflects the **planned v1.1 API** including the orientation-aware coordinate system and per-widget rotation. Fields marked ⚠️ *pending implementation* are not yet in the codebase.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [RadioKit (Main Object)](#2-radiokit-main-object)
   - [setOrientation()](#setorientation-)
   - [addWidget()](#addwidget-)
   - [begin()](#begin-)
   - [handle()](#handle-)
   - [isConnected()](#isconnected-)
   - [widgetCount()](#widgetcount-)
3. [Widgets — Input (App → Arduino)](#3-widgets--input-app--arduino)
   - [RadioKit_Button](#radiokit_button)
   - [RadioKit_Switch](#radiokit_switch)
   - [RadioKit_Slider](#radiokit_slider)
   - [RadioKit_Joystick](#radiokit_joystick)
4. [Widgets — Output (Arduino → App)](#4-widgets--output-arduino--app)
   - [RadioKit_LED](#radiokit_led)
   - [RadioKit_Text](#radiokit_text)
5. [Constants & Enums](#5-constants--enums)
6. [Coordinate System](#6-coordinate-system)
7. [Minimal Sketch Example](#7-minimal-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows this pattern:

```cpp
#include <RadioKit.h>

// 1. Declare widget objects globally
RadioKit_Button myButton;
RadioKit_LED    myLed;

void setup() {
    // 2. (Optional) Set orientation before begin()
    RadioKit.setOrientation(RK_LANDSCAPE);

    // 3. Register widgets with layout
    //    addWidget(widget, "Label", x, y, w, h)
    RadioKit.addWidget(myButton, "Fire",  50, 50, 30, 20);
    RadioKit.addWidget(myLed,    "Status", 150, 50, 15, 15);

    // 4. Start BLE advertising
    RadioKit.begin("MyDevice");
}

void loop() {
    // 5. Must be called every loop iteration
    RadioKit.handle();

    // 6. Read/write widget values
    if (myButton.pressed()) {
        myLed.set(RadioKit_LED::GREEN);
    }
}
```

---

## 2. RadioKit (Main Object)

`RadioKit` is a global singleton of type `RadioKitClass`. You never instantiate it yourself — just use `RadioKit.method()` directly.

---

### `setOrientation()` ⚠️ *pending implementation*

```cpp
void RadioKit.setOrientation(RadioKit_Orientation orientation);
```

Sets the virtual canvas orientation. Must be called **before** `begin()`. If not called, defaults to `RK_LANDSCAPE`.

| Parameter | Type | Description |
|---|---|---|
| `orientation` | `RadioKit_Orientation` | `RK_LANDSCAPE` (default) or `RK_PORTRAIT` |

**Canvas dimensions set by this call:**

| Orientation | Canvas Width | Canvas Height |
|---|---|---|
| `RK_LANDSCAPE` | 200 | 100 |
| `RK_PORTRAIT` | 100 | 200 |

**Example:**
```cpp
RadioKit.setOrientation(RK_PORTRAIT);
```

---

### `addWidget()`

```cpp
void RadioKit.addWidget(RadioKit_Widget& widget,
                        const char*      label,
                        uint8_t x, uint8_t y,
                        uint8_t w, uint8_t h,
                        int16_t rotation = 0);
```

Registers a widget and assigns its layout on the virtual canvas. Must be called **before** `begin()`. Widgets are assigned sequential IDs (0, 1, 2 …) in the order they are added.

| Parameter | Type | Description |
|---|---|---|
| `widget` | `RadioKit_Widget&` | Reference to a widget instance declared globally |
| `label` | `const char*` | Human-readable label shown in the app (max 32 chars) |
| `x` | `uint8_t` | Center X position on the virtual canvas |
| `y` | `uint8_t` | Center Y position on the virtual canvas |
| `w` | `uint8_t` | Widget width |
| `h` | `uint8_t` | Widget height |
| `rotation` | `int16_t` | ⚠️ Rotation in degrees `-180` to `+180`. Default `0`. Stored as mapped `int8_t` on wire. |

> **Coordinate origin:** `(0, 0)` is the **bottom-left** corner of the screen. X increases rightward, Y increases upward. `x` and `y` refer to the **center** of the widget.

> **Limits:** Maximum `RADIOKIT_MAX_WIDGETS` (16) widgets per sketch. Widgets added beyond this limit are silently ignored.

**Example:**
```cpp
RadioKit_Joystick joy;
RadioKit.addWidget(joy, "Drive", 50, 50, 40, 40);          // no rotation
RadioKit.addWidget(joy, "Drive", 50, 50, 40, 40, 90);      // rotated 90°
```

---

### `begin()`

```cpp
void RadioKit.begin(const char* deviceName);
```

Initialises BLE and starts advertising. Call once at the end of `setup()`, after all `addWidget()` calls.

| Parameter | Type | Description |
|---|---|---|
| `deviceName` | `const char*` | BLE device name visible to the app during scanning (e.g. `"MyRobot"`) |

**Example:**
```cpp
RadioKit.begin("CoolBot");
```

---

### `handle()`

```cpp
void RadioKit.handle();
```

Processes all pending BLE events and incoming protocol packets. **Must be called once per `loop()` iteration.** Handles connection state, `GET_CONF`, `GET_VARS`, `SET_INPUT`, and `PING` internally.

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

Returns `true` if a RadioKit Flutter app is currently connected over BLE.

**Example:**
```cpp
if (RadioKit.isConnected()) {
    digitalWrite(STATUS_LED, HIGH);
}
```

---

### `widgetCount()`

```cpp
uint8_t RadioKit.widgetCount() const;
```

Returns the number of widgets currently registered. Useful for debug output.

**Example:**
```cpp
Serial.println(RadioKit.widgetCount());  // e.g. prints 3
```

---

## 3. Widgets — Input (App → Arduino)

Input widgets receive values from the user's touches in the app. Their values are updated automatically by `RadioKit.handle()` each loop — you just read them.

---

### `RadioKit_Button`

A momentary push button. Sends `1` while pressed, `0` when released.

```cpp
RadioKit_Button myButton;
```

| Method | Returns | Description |
|---|---|---|
| `pressed()` | `bool` | `true` **once** on the leading edge of a press (rising edge), auto-clears on read |
| `isHeld()` | `bool` | `true` continuously for as long as the button is held down |

> Use `pressed()` for one-shot actions (toggle, fire, trigger). Use `isHeld()` for continuous actions (hold to move, hold to run).

**Example:**
```cpp
RadioKit_Button triggerBtn;

if (triggerBtn.pressed()) {
    fireProjectile();       // fires once per tap
}

if (triggerBtn.isHeld()) {
    runFan();               // runs continuously while held
}
```

---

### `RadioKit_Switch`

A toggle switch. Stays ON or OFF between user interactions.

```cpp
RadioKit_Switch mySwitch;
```

| Method | Returns | Description |
|---|---|---|
| `isOn()` | `bool` | `true` = switch is ON, `false` = switch is OFF |

**Example:**
```cpp
RadioKit_Switch lightSwitch;

digitalWrite(RELAY_PIN, lightSwitch.isOn() ? HIGH : LOW);
```

---

### `RadioKit_Slider`

A linear slider. Returns a value from `0` (left/bottom) to `100` (right/top).

```cpp
RadioKit_Slider mySlider;
```

| Method | Returns | Description |
|---|---|---|
| `value()` | `uint8_t` | Current slider position `0–100` |

**Example:**
```cpp
RadioKit_Slider speedSlider;

int pwm = map(speedSlider.value(), 0, 100, 0, 255);
analogWrite(MOTOR_PIN, pwm);
```

---

### `RadioKit_Joystick`

A 2-axis joystick. Reports signed X and Y axes independently.

```cpp
RadioKit_Joystick myJoystick;
```

| Method | Returns | Description |
|---|---|---|
| `x()` | `int8_t` | Horizontal axis: `-100` (full left) to `+100` (full right), `0` = center |
| `y()` | `int8_t` | Vertical axis: `-100` (full down) to `+100` (full up), `0` = center |

**Example:**
```cpp
RadioKit_Joystick driveStick;

// Differential drive mixing
int forward = driveStick.y();
int turn    = driveStick.x();
int leftPWM  = constrain(forward + turn, -100, 100);
int rightPWM = constrain(forward - turn, -100, 100);
```

---

## 4. Widgets — Output (Arduino → App)

Output widgets display values on the app screen. Set their value in your sketch; RadioKit sends them to the app automatically when polled.

---

### `RadioKit_LED`

An LED indicator displayed in the app. The Arduino controls its color.

```cpp
RadioKit_LED myLed;
```

| Method | Description |
|---|---|
| `set(RadioKit_LEDColor color)` | Set the LED color using one of the color constants below |
| `get()` | Returns the current `RadioKit_LEDColor` value |

**Color constants** (accessible as `RadioKit_LED::COLOR` or bare enum):

| Constant | Value | Display |
|---|---|---|
| `RadioKit_LED::OFF` | `0` | LED off (dark) |
| `RadioKit_LED::RED` | `1` | Red |
| `RadioKit_LED::GREEN` | `2` | Green |
| `RadioKit_LED::BLUE` | `3` | Blue |
| `RadioKit_LED::YELLOW` | `4` | Yellow |

**Example:**
```cpp
RadioKit_LED statusLed;

if (errorDetected) {
    statusLed.set(RadioKit_LED::RED);
} else {
    statusLed.set(RadioKit_LED::GREEN);
}
```

---

### `RadioKit_Text`

A text display label in the app. The Arduino pushes string content.

```cpp
RadioKit_Text myText;
```

| Method | Description |
|---|---|
| `set(const char* text)` | Set display string (max 32 chars, null-terminated, truncated if longer) |
| `set(const String& text)` | Arduino `String` overload — convenience wrapper |
| `get()` | Returns current text as `const char*` |

**Example:**
```cpp
RadioKit_Text sensorDisplay;

// From a C string
sensorDisplay.set("Ready");

// From sensor reading
sensorDisplay.set(String(analogRead(A0)));

// Formatted string
char buf[32];
snprintf(buf, sizeof(buf), "Temp: %d C", temperature);
sensorDisplay.set(buf);
```

---

## 5. Constants & Enums

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

### Widget Limits

```cpp
#define RADIOKIT_MAX_WIDGETS   16    // maximum registered widgets per sketch
#define RADIOKIT_MAX_LABEL     32    // maximum label string length (chars)
#define RADIOKIT_TEXT_LEN      32    // maximum RadioKit_Text display string length
```

### LED Colors

```cpp
enum RadioKit_LEDColor : uint8_t {
    LED_OFF    = 0,
    LED_RED    = 1,
    LED_GREEN  = 2,
    LED_BLUE   = 3,
    LED_YELLOW = 4
};
```

### Widget Type IDs (internal — for protocol reference)

```cpp
#define RADIOKIT_TYPE_BUTTON   0x01
#define RADIOKIT_TYPE_SWITCH   0x02
#define RADIOKIT_TYPE_SLIDER   0x03
#define RADIOKIT_TYPE_JOYSTICK 0x04
#define RADIOKIT_TYPE_LED      0x05
#define RADIOKIT_TYPE_TEXT     0x06
```

---

## 6. Coordinate System

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

`x` and `y` in `addWidget()` refer to the **center** of the widget:

```
        ┌──────────┐
        │          │  H
        │  (x, y)  │
        │  center  │
        └──────────┘
             W
```

### Rotation ⚠️ *pending implementation*

- User API: `-180°` to `+180°`
- Wire encoding: `int8_t` from `-90` to `+90` (divide by 2 for storage, multiply by 2 to recover)
- Positive = counter-clockwise (standard mathematical convention)
- Default = `0` (no rotation)

---

## 7. Minimal Sketch Example

```cpp
#include <RadioKit.h>

RadioKit_Button  fireBtn;
RadioKit_Slider  speedSlider;
RadioKit_Joystick driveStick;
RadioKit_LED     statusLed;
RadioKit_Text    readout;

void setup() {
    RadioKit.setOrientation(RK_LANDSCAPE);

    //                widget       label      x    y    w    h
    RadioKit.addWidget(fireBtn,    "Fire",    20,  50,  25,  20);
    RadioKit.addWidget(speedSlider,"Speed",   100, 15,  60,  12);
    RadioKit.addWidget(driveStick, "Drive",   160, 50,  35,  35);
    RadioKit.addWidget(statusLed,  "Status",  20,  20,  12,  12);
    RadioKit.addWidget(readout,    "Sensor",  100, 80,  70,  15);

    RadioKit.begin("DemoBot");
}

void loop() {
    RadioKit.handle();

    if (fireBtn.pressed()) {
        statusLed.set(RadioKit_LED::RED);
    }

    int speed = map(speedSlider.value(), 0, 100, 0, 255);
    analogWrite(MOTOR_PIN, speed);

    char buf[32];
    snprintf(buf, sizeof(buf), "A0=%d", analogRead(A0));
    readout.set(buf);

    if (!RadioKit.isConnected()) {
        statusLed.set(RadioKit_LED::OFF);
    }
}
```
