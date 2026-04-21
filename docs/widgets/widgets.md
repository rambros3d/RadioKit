# RadioKit Library - Widgets Reference

> This document covers widget composition, class references, and constants.

---

## Table of Contents

1. [Widget Composition (Specific Props)](#1-widget-composition-specific-props)
2. [Widget Class Reference](#2-widget-class-reference)
  - [Push & Toggle Buttons](#push--toggle-buttons)
  - [SlideSwitch](#slideswitch)
  - [Slider](#slider)
  - [Knob](#knob)
  - [Joystick](#joystick)
  - [MultipleButton / MultipleSelect](#multiplebutton--multipleselect)
  - [LED](#led)
  - [Text](#text)
3. [Constants & Enums](#3-constants--enums)

---

## 1. Widget Composition (Specific Props)

In v2.0, each widget uses its own **Tailored Struct** to minimize RAM waste. Every widget provides the same core fields (`label`, `x`, `y`), but only allocates memory for features it actually uses.

### Hybrid Access Model

Every widget provides two ways to access its data. All widgets contain a public member `props` of a tailored type (e.g. `RK_ButtonProps`).

#### A. The "Method" Interface (Read/Write)

Best for standard control logic. Clean, type-safe, and self-documenting.

- `if (btn.get())` — Checking a button state.

#### B. The "Props" Interface (Deep access)

Best for dynamic UI changes. Since `props` is public, you can modify any part of the widget's metadata at runtime.

- `slider.props.label = "Volt"` — Changing a label dynamically.

### Instantiation Pattern

RadioKit uses a specialized pattern that bridges **Data (Props)** and **Logic (Classes)**:

1. **The Struct**: `RK_SliderProps` is a plain data container.
2. **The Class**: `RK_Slider` is the active controller.
3. **The Bridge**: When you instantiate a widget, you pass an **initializer list** `{ ... }`. The compiler implicitly creates the `Props` struct and hands it to the `Class` constructor.

```cpp
// { ... } creates the Props, RK_Slider creates the Controller
RK_Slider speed({ .label="Speed", .value=50 }); 
```

### Common variables

All widgets share these positional and dimensional parameters:

| Variable       | Type        | Description                                            | Default |
|----------------|-------------|--------------------------------------------------------|---------|
| **x**, **y**   | uint8       | Center position in virtual canvas units (0–200).       | 100, 100|
| **width**      | uint8       | Width multiplier × 10 (e.g., 20 = 2.0×).               | 10      |
| **height**     | uint8       | Height multiplier × 10 (e.g., 10 = 1.0×).              | 10      |
| **rotation**   | int16       | Rotation in degrees (clockwise).                       | 0       |
| **style**      | uint8       | Visual style ID (Theme/Color variant).                 | 0       |

### Layout Calculation

The final physical size on screen is calculated using a **Baseline × Scale** model:

1.  **Baseline Dimensions**: Fixed values per widget type (at scale 1.0).
    *   **BaseHeight**: Default height for all widgets (commonly 10 units).
    *   **Aspect Ratio**: Default aspect for the type (e.g., 5.0 for Slider). 
2.  **Final Dimensions**:
    *   `Height = BaseHeight * scale_height`
    *   `Width  = (BaseHeight * Aspect) * scale_height * ExtraWidthScale`
        *   `ExtraWidthScale` is only active for resizable widgets (Slider, Text) via the `width` parameter.
        *   For all other widgets, it is locked to `1.0`.

> [!TIP]
> This model ensure that widgets scale proportionally when only `height` is changed, while still allowing independent width control for resizable types.

---

## 2. Widget Class Reference

### Push & Toggle Buttons

The primary binary input widgets.

- **PushButton**: Momentary interaction (returns `true` only while held).
- **ToggleButton**: Latched interaction (toggles between `true` and `false` on tap).

**Unified Structure:**

```cpp
struct RK_ButtonProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       height = 1.0;
    //--------------------------
    uint8_t     style = 0;
    bool        state = false;
    const char* onText = nullptr; 
    const char* offText = nullptr;
};
```


| Function           | Variable (Direct Access) | Description                                |
| ------------------ | ------------------------ | ------------------------------------------ |
| `get()`            | `props.state == true`    | Returns `true` if active.                  |
| `set(bool)`        | `props.state = val;`     | Force update the app-side state.           |
| `setIcon(char*)`   | `props.icon = val;`      | Updates icon (e.g. "wifi", "wifi-off").    |


**Examples:**

```cpp
// A red momentary button with an icon
RK_PushButton fire({ .label="FIRE", .x=200, .y=50, .style=RK_DANGER, .icon="flame" });

// A master toggle switch (ToggleButton)
RK_ToggleButton power({ 
    .label = "Power", 
    .x = 50, 
    .y = 80, 
    .state = true,
    .icon = "power",
    .onText = "ON", 
    .offText = "OFF" 
});
```

---

### SlideSwitch

iOS-style slide/toggle switch for binary on/off control. Unlike `ToggleButton` (which renders as a button), `SlideSwitch` renders as a horizontal track with a sliding thumb.

**Structure:**

```cpp
struct RK_SlideSwitchProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       height = 1.0;
    //--------------------------
    uint8_t     style = 0;
    bool        state = false;
    const char* onText = nullptr;
    const char* offText = nullptr;
};
```


| Function           | Variable (Direct Access) | Description                                |
| ------------------ | ------------------------ | ------------------------------------------ |
| `get()`            | `props.state == true`    | Returns `true` if active.                  |
| `set(bool)`        | `props.state = val;`     | Force update the app-side state.           |
| `setIcon(char*)`   | `props.icon = val;`      | Updates icon (e.g. "wifi", "wifi-off").    |


**Example:**

```cpp
RK_SlideSwitch headlights({
    .label = "Headlights",
    .x = 50,
    .y = 60,
    .state = false,
    .icon = "sun",
    .onText = "ON",
    .offText = "OFF"
});
```

---

### Slider

Linear analog input control (−100 to +100).

RadioKit v1.6 uses a **Spring Simulation Engine** to handle the movement of the slider. While the hardware defines the functional centering, the skin definition (`config.json`) determines the aesthetic character (damping, stiffness) of the return animation.

The `variant` byte encodes both **centering mode** and **detent count** via the `RK_VARIANT()` macro (see [Constants](#5-constants--enums)).

**Structure:**

```cpp
struct RK_SliderProps {
    const char* label    = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       width    = 1.0;
    float       height   = 1.0;
    //--------------------------
    uint8_t     centering = RK_CENTER_NONE; // RK_CENTER_NONE/LEFT/CENTER/RIGHT
    uint8_t     detents   = 0;             // 0=continuous, 1-63=snap positions
    int8_t      value     = 0;             // -100 to +100
};
```

| Function     | Variable (Direct Access) | Description                          |
| ------------ | ------------------------ | ------------------------------------ |
| `get()`      | `props.value`            | Returns position (−100 to +100).     |
| `set(v)`     | `props.value = val;`     | Force update app position (−100..+100). |
| `centering()`| `props.centering`        | Returns the centering mode.          |
| `detents()`  | `props.detents`          | Returns the detent count.            |


**Examples:**

```cpp
// Continuous horizontal slider, full range:
RK_Slider throttle({ .label="Throttle", .x=50, .y=40, .width=2.5 });

// Spring-returns to centre (e.g. trim / pitch):
RK_Slider pitch({ .label="Pitch", .centering=RK_CENTER, .x=80, .y=40 });

// 5-position detent slider (snaps to -100, -50, 0, +50, +100):
RK_Slider gear({ .label="Gear", .detents=5, .x=120, .y=40 });
```

---

### Knob

Rotary analog input control (−100 to +100). Identical wire format to `RK_Slider` but rendered as a 270° circular arc knob with a vertical-drag gesture.

Like the Slider, the Knob utilizes the **Spring Simulation Engine** for consistent, premium haptic response when returning to center or snapping to detents.

The `variant` byte encodes both **centering mode** and **detent count** via the `RK_VARIANT()` macro (see [Constants](#5-constants--enums)).

**Structure:**

```cpp
struct RK_KnobProps {
    const char* label    = nullptr;
    const char* icon     = nullptr; // Shown on knob face
    uint8_t     x = 0, y = 0;
    float       height    = 1.0;
    uint8_t     style    = 0;
    //--------------------------
    uint8_t     centering = RK_CENTER_NONE;
    uint8_t     detents   = 0;
    int8_t      value     = 0; // -100 to +100
};
```

| Function     | Variable (Direct Access) | Description                          |
| ------------ | ------------------------ | ------------------------------------ |
| `get()`      | `props.value`            | Returns position (−100 to +100).     |
| `set(v)`     | `props.value = val;`     | Force update app position (−100..+100). |
| `centering()`| `props.centering`        | Returns the centering mode.          |
| `detents()`  | `props.detents`          | Returns the detent count.            |


**Examples:**

```cpp
// Panning knob (spring-returns to centre):
RK_Knob pan({ .label="Pan", .centering=RK_CENTER, .x=100, .y=60 });

// Volume knob (continuous, 12 o'clock = 0):
RK_Knob vol({ .label="Vol", .x=140, .y=60, .icon="volume-2" });

// 5-detent EQ knob (-100, -50, 0, +50, +100):
RK_Knob eq({ .label="Bass", .detents=5, .x=180, .y=60 });
```

---

### Joystick

2-axis analog controller (-100 to +100). 

Interaction in v1.6 is powered by two independent **Spring Simulations** for the X and Y axes, allowing skin creators to define the precise "stiffness" and "bounciness" of the stick return.

**Structure:**

```cpp
struct RK_JoystickProps {
    const char* label = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       height = 1.0;
    bool        enabled = true;
    uint8_t     variant = 0;
    //--------------------------
    int8_t      xvalue = 0;
    int8_t      yvalue = 0;
};
```


| Function | Variable (Direct Access) | Description     |
| -------- | ------------------------ | --------------- |
| `getX()` | `props.xvalue`           | Returns X-axis. |
| `getY()` | `props.yvalue`           | Returns Y-axis. |


#### Joystick Variants (`variant`)


| Value | Name               | Behavior                          |
| ----- | ------------------ | --------------------------------- |
| `0`   | **Self-Centering** | Centering for both X,Y (Default). |
| `1`   | **No-Centering**   | No Centering for X,Y.             |


**Example:**

```cpp
RK_Joystick drive({ 
    .x = 180, 
    .y = 50, 
    .rotation = 90,
    .variant = 1 // No centering
});
```

---

### MultipleButton / MultipleSelect

Selection groups (Radio or Checkbox). State is an **8-bit Bitmask**.

**Widget Structure:**

```cpp
struct RK_MultipleProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       height = 1.0;
    //--------------------------
    uint8_t     style = 0;
    uint8_t     variant = 0;
    uint8_t     value = 0;
    std::initializer_list<RK_Item> items = {};
};
```

**Item Structure:**

```cpp
struct RK_Item {
    const char* label = nullptr; // Display text
    const char* icon  = nullptr; // Optional Icon name
    uint8_t     pos   = 255;     // Fixed bitmask position (0-7). 255 = Auto.
};
```

> [!NOTE]
> These widgets use a **Fixed 8-Slot Memory Pool** managed by the class. The `initializer_list` in the struct passes your initial items into this pre-allocated storage.


| Function         | Variable (Direct Access)             | Description                          |
| ---------------- | ------------------------------------ | ------------------------------------ |
| `get()`          | `props.value`                        | Returns current bitmask (`uint8_t`). |
| `get(index)`     | `(props.value & (1 << index))`       | Returns `true` if index is active.   |
| `clear()`        | `props.items = {}; props.value = 0;` | Removes all items.                   |
| `add(RK_Item)`   | (Implicit Pool access)               | Adds an item to the pool (Max 8).    |
| `remove(index)`  | (Implicit Pool access)               | Removes an item by index.            |
| `setIcon(char*)` | `props.icon = val;`                  | Updates group heading icon.          |


**Example:**

```cpp
RK_MultipleSelect toolbar({
    .label = "Systems",
    .icon = "settings",
    .x = 100, 
    .y = 20,
    .items = {
        { .label="WiFi", .icon="wifi", .pos=0 },
        { .label="BT",   .icon="bt",   .pos=1 }
    }
});
```

---

### LED

Visual status indicator (Arduino -> App).

**Structure:**

```cpp
struct RK_LEDProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       height = 1.0;
    //--------------------------
    uint8_t     style = 0;
    bool        state = false;
    uint8_t     red = 255, green = 0, blue = 0;
    uint8_t     opacity = 255;
};
```


| Function           | Variable (Direct Access) | Description                      |
| ------------------ | ------------------------ | -------------------------------- |
| `on()`             | `props.state = true;`    | Turns LED ON.                    |
| `off()`            | `props.state = false;`   | Turns LED OFF.                   |
| `setIcon(char*)`   | `props.icon = val;`      | Updates icon (e.g. "battery").   |
| `setColor(hex)`    | none                     | Accepts 6 (RGB) or 8 (RGBA) hex. |
| `setOpacity(val)`  | `props.opacity = val;`   | Sets transparency (0-255).       |
| `setRed(val)`      | `props.red = val;`       | Sets red component (0-255).      |
| `setGreen(val)`    | `props.green = val;`     | Sets green component (0-255).    |
| `setBlue(val)`     | `props.blue = val;`      | Sets blue component (0-255).     |


**Example:**

```cpp
RK_LED telemetryOK({ 
    .x = 10, 
    .y = 10, 
    .icon = "check-circle",
    .red = 0, .green = 255, .blue = 0, // Green
    .state = true 
});
```

---

### Text

Dynamic text display label (Arduino -> App).

**Structure:**

```cpp
struct RK_TextProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       width = 1.0;
    float       height = 1.0;
    //--------------------------
    uint8_t     style = 0;
    const char* text = nullptr;
};
```


| Function           | Variable (Direct Access) | Description                           |
| ------------------ | ------------------------ | ------------------------------------- |
| `set(const char*)` | `props.text = val;`      | Updates text content.                 |
| `setIcon(char*)`   | `props.icon = val;`      | Updates prefix icon (e.g. "message"). |


**Example:**

```cpp
RK_Text status({ 
    .label = "LOG:", 
    .x = 50, 
    .y = 10, 
    .icon = "terminal",
    .text = "System Ready" 
});
```

---

## 3. Constants & Enums

### Architecture (`architecture`)

- `RK_ARCH_UNKNOWN` (0)
- `RK_ARCH_ESP32`   (1)
- `RK_ARCH_NORDIC`  (2)
- `RK_ARCH_SAMD`    (3)
- `RK_ARCH_STM32`   (4)

### Slider / Knob Centering Modes

Passed as the `centering` field of `RK_SliderProps` / `RK_KnobProps`.

| Constant | Value | Behaviour |
| --- | --- | --- |
| `RK_CENTER_NONE` | `0` | No spring return — stays where released (default). |
| `RK_CENTER_LEFT` | `1` | Springs to −100 on release. |
| `RK_CENTER`      | `2` | Springs to 0 (centre) on release. |
| `RK_CENTER_RIGHT`| `3` | Springs to +100 on release. |

### `RK_VARIANT()` Macro

Packs a centering mode and a detent count into the single `variant` byte:

```cpp
// Syntax
RK_VARIANT(centering, detents)
//   centering : RK_CENTER_NONE / LEFT / CENTER / RIGHT
//   detents   : 0 = continuous; 1–63 = number of snap positions

// Examples
RK_VARIANT(RK_CENTER, 0)   // spring-to-centre, continuous
RK_VARIANT(RK_CENTER_NONE, 5) // no spring, 5 snap positions
```

When using `RK_SliderProps` or `RK_KnobProps`, you can set `centering` and `detents` directly — the constructor packs them automatically. Use `RK_VARIANT()` only when constructing the raw `variant` byte manually.

### UI Theme

RadioKit uses string-based identifiers for UI skins. For a full list of built-in skins and details on custom skin packs, refer to **[UI Skins Documentation](UI_SKINS.md)**.

### Widget Styles

- `RK_PRIMARY` (0)
- `RK_DIM` (1)

these styles are supported only by Buttons, LEDs, and Text
- `RK_SUCCESS` (2)
- `RK_WARNING` (3)
- `RK_DANGER` (4)

### Colors

| Name        | Hex Mapping |
| ----------- | ----------- |
| `RK_OFF`    | `0x000000`  |
| `RK_RED`    | `0xFF0000`  |
| `RK_GREEN`  | `0x00FF00`  |
| `RK_BLUE`   | `0x0000FF`  |
| `RK_YELLOW` | `0xFFFF00`  |
