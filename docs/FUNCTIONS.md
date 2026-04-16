# RadioKit Library - Functions Reference

> This document reflects the **v2.0 Object-Oriented API** using **Tailored Initializers**.

---

## Table of Contents

1. [Setup & Sketch Structure](#setup--sketch-structure)
2. [RadioKit (Main Object)](#2-radiokit-main-object)
3. [Widget Composition (Specific Props)](#3-widget-composition-specific-props)
4. [Widget Class Reference](#4-widget-class-reference)
  - [Push & Toggle Buttons](#push--toggle-buttons)
  - [SlideSwitch](#slideswitch)
  - [Slider](#slider)
  - [Joystick](#joystick)
  - [MultipleButton / MultipleSelect](#multiplebutton--multipleselect)
  - [LED](#led)
  - [Text](#text)
5. [Constants & Enums](#5-constants--enums)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a simple three-part pattern. 

```cpp
#include <RadioKit.h>

// ── 1. Widget declarations (global scope) ────────────────────────────────
RK_PushButton fireBtn({ .label="Fire", .x=20, .y=50, .scale=1.5, .icon="flame" });

// ── 2. setup() ───────────────────────────────────────────────────────────
void setup() {
    RadioKit.config.name = "GP7 Locomotive";
    RadioKit.config.password = "1234";
    RadioKit.config.theme = "retro"; // Controller skin name or GitHub URL
    RadioKit.begin();
    RadioKit.startBLE("Train_01");
}

// ── 3. loop() ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
}
```

---

## 2. RadioKit (Main Object)

### `begin()`

Commits and synchronizes configuration. Must be called in `setup()`.

```cpp
void begin();
```

### `config` (Object)

Global settings object.

#### User Configurable


| Field             | Type          | Description                                                     |
| ----------------- | ------------- | --------------------------------------------------------------- |
| `**name**`        | `const char*` | Model or Device name. Sent to app on connection.                |
| `**password**`    | `const char*` | Optional connection password (leave empty for none).            |
| `**description**` | `const char*` | Short overview of the device's function.                        |
| `**version**`     | `const char*` | User-defined firmware version string (e.g. `"1.0.4"`).          |
| `**theme**`       | `const char*` | Controller skin identifier. Supports built-in names or GitHub URLs. See [UI Skins](file:///home/sun/Apps/RadioKit/docs/UI_SKINS.md). |
| `**type**`        | `const char*` | Category of device (e.g. `"truck"`, `"robot"`, `"locomotive"`). |
| `**orientation**` | `uint8_t`     | `RK_LANDSCAPE` (Default) or `RK_PORTRAIT`.                      |
| `**width**`       | `uint8_t`     | Canvas width (0-250).                                           |
| `**height**`      | `uint8_t`     | Canvas height (0-250).                                          |


#### Read-Only (Set by Library)


| Field              | Type          | Description                                        |
| ------------------ | ------------- | -------------------------------------------------- |
| `**architecture**` | `uint8_t`     | Detected hardware platform (e.g. `RK_ARCH_ESP32`). |
| `**libversion**`   | `const char*` | Current RadioKit library version string.           |


---

## 3. Widget Composition (Specific Props)

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


| Field            | Type          | Description                                            | Default  |
| ---------------- | ------------- | ------------------------------------------------------ | -------- |
| `**label**`      | `const char*` | The text label displayed.                              | REQUIRED |
| `**icon**`       | `const char*` | Optional icon name (e.g. "wifi")                       | `nullptr`|
| `**x**`, `**y**` | `uint8_t`     | Center coordinates ($0\dots 250$).                     | REQUIRED |
| `**rotation**`   | `int16_t`     | Rotation in degrees.                                   | `0`      |
| `**scale**`      | `float`       | Global size multiplier.                                | `1.0`    |
| `**aspect**`     | `float`       | Width/Height ratio.                                    | `1.0`    |
| `**enabled**`    | `bool`        | Visibility and traffic toggle.                         | `true`   |
| `**variant**`    | `uint8_t`     | Widget-specific variation (visual style).              | `0`      |
| `**style**`      | `uint8_t`     | Visual theme index (Primary, Secondary, Danger, etc.). | `0`      |


---

## 4. Widget Class Reference

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
    float       scale = 1.0;
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
    float       scale = 1.0;
    float       aspect = 1.0;
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

Analog input slider (0-100).

**Structure:**

```cpp
struct RK_SliderProps {
    const char* label = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0;
    float       aspect = 1.0;
    //--------------------------
    uint8_t     variant = 0;
    uint8_t     value = 0; 
};
```

| Value | Name               | Behavior                          |
| ----- | ------------------ | --------------------------------- |
| `0`   | **Self-Centering Middle** | Center to middle |
| `1`   | **Self-Centering Top** | Center to top |
| `2`   | **Self-Centering Bottom** | Center to bottom |    
| `3`   | **No-Centering**   | No Centering            |


| Function     | Variable (Direct Access) | Description                        |
| ------------ | ------------------------ | ---------------------------------- |
| `get()`      | `props.value`            | Returns position (0-100).          |
| `set(value)` | `props.value = val;`     | Force update app position (0-100). |


**Example:**

```cpp
RK_Slider speed({ 
    .label = "Speed", 
    .x = 50, 
    .y = 40, 
    .aspect = 2.5, 
    .value = 25 
});
```

---

### Joystick

2-axis analog controller (-100 to +100).

**Structure:**

```cpp
struct RK_JoystickProps {
    const char* label = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0;
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
    float       scale = 1.0;
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
    float       scale = 1.0;
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
    float       scale = 1.0;
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

## 5. Constants & Enums

### Architecture (`architecture`)

- `RK_ARCH_UNKNOWN` (0)
- `RK_ARCH_ESP32`   (1)
- `RK_ARCH_NORDIC`  (2)
- `RK_ARCH_SAMD`    (3)
- `RK_ARCH_STM32`   (4)

### UI Theme

RadioKit uses string-based identifiers for UI skins. For a full list of built-in skins and details on custom skin packs, refer to **[UI Skins Documentation](file:///home/sun/Apps/RadioKit/docs/UI_SKINS.md)**.

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
