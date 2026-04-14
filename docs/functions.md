# RadioKit Library — Function Reference

> **Note:** This document reflects the **v2.0 Object-Oriented API**. This version uses auto-detecting widget objects and a flexible **Size & Aspect Ratio** layout model.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [Common Widget Methods](#2-common-widget-methods)
3. [Widget Class Reference](#3-widget-class-reference)
   - [RadioKit_Button](#radiokit_button)
   - [RadioKit_Switch](#radiokit_switch)
   - [RadioKit_Slider](#radiokit_slider)
   - [RadioKit_Joystick](#radiokit_joystick)
   - [RadioKit_LED](#radiokit_led)
   - [RadioKit_Text](#radiokit_text)
4. [RadioKit (Main Object)](#4-radiokit-main-object)
   - [startBLE()](#startble)
   - [update()](#update)
   - [isConnected()](#isconnected)
5. [Coordinate System](#5-coordinate-system)
6. [Constants & Enums](#6-constants--enums)
7. [Full Sketch Example](#7-full-sketch-example)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows this simple three-part pattern. Widgets **register themselves automatically** upon declaration.

```cpp
#include <RadioKit.h>

// ── Part 1: Widget declarations ──────────────────────────────────────────
// Format: [Label (optional)], x, y, size (Height), [aspectRatio (optional)]
// aspect = 0 (default) means "auto-calculate for this widget type"
RadioKit_Button fireBtn("Fire", 20, 50, 25);
RadioKit_LED    statusLed(20, 20, 12);

// ── Part 2: setup() ──────────────────────────────────────────────────────
void setup() {
    RadioKit.startBLE("MyDevice"); 
}

// ── Part 3: loop() ───────────────────────────────────────────────────────
void loop() {
    RadioKit.update();

    if (fireBtn.isPressed()) {
        statusLed.set(RadioKit_LED::GREEN);
    }
}
```

---

## 2. Common Widget Methods

All widgets inherit these methods for runtime configuration.

### `setPosition()`
```cpp
void setPosition(uint8_t x, uint8_t y);
void setPosition(uint8_t x, uint8_t y, int16_t rotation);
```
Updates the widget's center point and optionally its rotation.

### `setSize()`
```cpp
void setSize(uint8_t size);
void setSize(uint8_t width, uint8_t height); // Automatically updates aspect ratio
```
Updates the widget's scale. If two values are provided, they set the width and height explicitly (updating the internal aspect ratio).

### `show()` / `hide()`
```cpp
void show();
void hide();
```
Controls the visibility of the widget in the app.

---

## 3. Widget Class Reference

All constructors share a similar signature: **Label is optional** and comes first, followed by coordinates (`x`, `y`), then `size`, and finally an optional `aspectRatio`.

> **Note on Aspect Ratio**: A value of `0` (the default) tells the library to use the widget's ideal default ratio.

### `RadioKit_Button`
- **Constructors:**
  - `RadioKit_Button(label, x, y, size, aspect = 0)`
  - `RadioKit_Button(x, y, size, aspect = 0)`
- **Default Aspect**: `2.5` (Landscape button)

### `RadioKit_Switch`
- **Constructors:**
  - `RadioKit_Switch(label, x, y, size, aspect = 0)`
  - `RadioKit_Switch(x, y, size, aspect = 0)`
- **Default Aspect**: `1.6`

### `RadioKit_Slider`
- **Constructors:**
  - `RadioKit_Slider(label, x, y, size, aspect = 0)`
  - `RadioKit_Slider(x, y, size, aspect = 0)`
- **Default Aspect**: `5.0` (Thin bar)

### `RadioKit_Joystick`
- **Constructors:**
  - `RadioKit_Joystick(label, x, y, size, aspect = 0)`
  - `RadioKit_Joystick(x, y, size, aspect = 0)`
- **Default Aspect**: `1.0` (Square)

### `RadioKit_LED`
- **Constructors:**
  - `RadioKit_LED(label, x, y, size, aspect = 0)`
  - `RadioKit_LED(x, y, size, aspect = 0)`
- **Default Aspect**: `1.0` (Circular)

### `RadioKit_Text`
- **Constructors:**
  - `RadioKit_Text(label, x, y, size, aspect = 0)`
  - `RadioKit_Text(x, y, size, aspect = 0)`
- **Default Aspect**: `4.0`

---

## 4. RadioKit (Main Object)

### `startBLE()`
```cpp
void RadioKit.startBLE(const char* deviceName, const char* password = nullptr);
```

### `update()`
```cpp
void RadioKit.update();
```

---

## 5. Coordinate System

- **Units**: Relative 0–200 scale.
- **Origin (0, 0)**: Bottom-left.
- **Positions**: Center point.

---

## 6. Full Sketch Example

```cpp
#include <RadioKit.h>

RadioKit_Joystick joy("Drive", 160, 50, 35);
RadioKit_LED      led(20, 20, 15);
RadioKit_Slider   power("Power", 100, 20, 80);

void setup() {
    RadioKit.startBLE("RoboCar");
}

void loop() {
    RadioKit.update();

    if (RadioKit.isConnected()) {
        // Change aspect ratio based on joystick X
        // size remains 35, box becomes wider/thinner
        float ratio = 1.0f + (joy.getX() / 100.0f);
        joy.setSize(35); // base size
        
        if (abs(joy.getX()) > 50) led.set(RadioKit_LED::RED);
        else led.set(RadioKit_LED::BLUE);
    }
}
```