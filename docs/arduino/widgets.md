# RadioKit Library - Widgets Reference

> This document covers widget composition, class references, and constants for RadioKit v2.0.

---

## Table of Contents

1. [Widget Composition (Specific Props)](#1-widget-composition-specific-props)
2. [Widget Class Reference](#2-widget-class-reference)
   - [PushButton & ToggleButton](#pushbutton--togglebutton)
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

In v2.0, each widget uses its own **Tailored Struct** to minimize RAM waste. Every widget provides the same core fields (`label`, `x`, `y`, `scale`), but only allocates memory for features it actually uses.

### Hybrid Access Model

Every widget provides two ways to access its data:

#### A. The Method Interface (Read/Write)

Best for standard control logic. Clean, type-safe, and self-documenting.

```cpp
if (btn.isPressed()) { ... }     // Checking a button state
int8_t val = sld.get();          // Reading slider position
```

#### B. The Props Interface (Deep Access)

Best for dynamic UI changes. Since `props` is public, you can modify any part of the widget's metadata at runtime.

```cpp
slider.props.label = "Volume";   // Changing a label dynamically
slider.props.value = 50;         // Direct value assignment
```

### Instantiation Pattern

RadioKit uses a specialized pattern that bridges **Data (Props)** and **Logic (Classes)**:

1. **The Struct**: `RK_SliderProps` is a plain data container (POD).
2. **The Class**: `RK_Slider` is the active controller with methods.
3. **The Bridge**: When you instantiate a widget, you pass an **initializer list** `{ ... }`. The compiler implicitly creates the `Props` struct and hands it to the `Class` constructor.

```cpp
// { ... } creates the Props, RK_Slider creates the Controller
RK_Slider speed({ .label="Speed", .value=50, .x=100, .y=60, .aspect=8.0f });
```

### Common Variables

All widgets share these positional and dimensional parameters:

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `x`, `y` | `uint8` | Center position in virtual canvas (0–200). | 100, 100 |
| `scale` | `float` | Size multiplier (1.0 = baseline). | 1.0 |
| `rotation` | `int16` | Rotation in degrees (clockwise). | 0 |
| `label` | `const char*` | Text label above/beside widget. | `nullptr` |
| `icon` | `const char*` | Icon name (from skin). | `nullptr` |
| `style` | `uint8` | Visual style ID (0=primary, 1=dim, 2=success, 3=warning, 4=danger). | 0 |

### Layout Calculation

The final physical size on screen uses a **Baseline × Scale** model:

1. **Baseline Dimensions**: Fixed values per widget type (at scale 1.0).
   - **BaseHeight**: Default height for all widgets (commonly 10 virtual units).
   - **Aspect Ratio**: Default aspect for the type (e.g., 5.0 for Slider).

2. **Final Dimensions**:
   - `Height = BaseHeight × scale`
   - `Width  = (BaseHeight × Aspect) × scale × ExtraWidthScale`
     - `ExtraWidthScale` is only active for resizable widgets (Slider, Text) via the `aspect` parameter.
     - For all other widgets, it is locked to `1.0`.

> **Tip:** This model ensures that widgets scale proportionally when only `scale` is changed, while still allowing independent width control for resizable types.

---

## 2. Widget Class Reference

### PushButton & ToggleButton

The primary binary input widgets.

- **PushButton**: Momentary interaction (returns `true` only while held).
- **ToggleButton**: Latched interaction (toggles between `true` and `false` on tap).

**Structure:**

```cpp
struct RK_ButtonProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    uint8_t     style = 0;
    bool        state = false;
    const char* onText = nullptr;
    const char* offText = nullptr;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `isPressed()` | `props.state == true` | Returns `true` if actively pressed (PushButton only). |
| `get()` | `props.state == true` | Returns `true` if active/toggled (ToggleButton). |
| `set(bool)` | `props.state = val;` | Force update the app-side state. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon (e.g. `"power"`, `"wifi"`). |

**Examples:**

```cpp
// A momentary fire button with an icon
RK_PushButton fire({
    .label = "FIRE",
    .x = 20, .y = 50,
    .scale = 2.0f,
    .style = RK_DANGER,
    .icon = "flame"
});

// A master power toggle
RK_ToggleButton power({
    .label = "Power",
    .x = 20, .y = 80,
    .scale = 2.0f,
    .icon = "power",
    .onText = "ON",
    .offText = "OFF"
});

// Usage in loop()
void loop() {
    RadioKit.update();
    
    if (fire.isPressed()) {
        // Activate while held
        triggerFire();
    }
    
    if (power.get()) {
        // Power is ON
        enableSystems();
    }
}
```

---

### SlideSwitch

iOS-style slide/toggle switch for binary on/off control.

> **Skin folder**: `toggle_switch/` – assets reside in the `toggle_switch/` directory of a skin pack.

**Structure:**

```cpp
struct RK_SlideSwitchProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    uint8_t     style = 0;
    bool        state = false;
    const char* onText = nullptr;
    const char* offText = nullptr;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.state == true` | Returns `true` if active. |
| `set(bool)` | `props.state = val;` | Force update the app-side state. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon. |

**Example:**

```cpp
RK_SlideSwitch headlights({
    .label = "Headlights",
    .x = 50, .y = 60,
    .scale = 1.5f,
    .state = false,
    .icon = "sun",
    .onText = "ON",
    .offText = "OFF"
});

void loop() {
    RadioKit.update();
    digitalWrite(LED_PIN, headlights.get() ? HIGH : LOW);
}
```

---

### Slider

Linear analog input control (−100 to +100).

RadioKit v1.6+ uses a **Spring Simulation Engine** for the slider thumb. The skin definition (`config.json`) determines the aesthetic character (damping, stiffness) of the return animation.

The `variant` byte encodes both **centering mode** and **detent count** via the `RK_VARIANT()` macro (see [Constants](#3-constants--enums)).

**Structure:**

```cpp
struct RK_SliderProps {
    const char* label    = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale    = 1.0f;
    float       aspect   = 5.0f;   // Width multiplier (5.0 = 5× height)
    //--------------------------
    uint8_t     centering = RK_CENTER_NONE; // RK_CENTER_NONE/LEFT/CENTER/RIGHT
    uint8_t     detents   = 0;      // 0=continuous, 1-63=snap positions
    int8_t      value     = 0;      // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns position (−100 to +100). |
| `set(int8_t)` | `props.value = val;` | Force update app position (−100..+100). |
| `centering()` | `props.centering` | Returns the centering mode. |
| `detents()` | `props.detents` | Returns the detent count. |

**Examples:**

```cpp
// Continuous horizontal slider, full range
RK_Slider throttle({
    .label = "Throttle",
    .x = 50, .y = 40,
    .aspect = 8.0f,   // Extra wide
    .value = 0
});

// Spring-returns to centre (e.g. trim / pitch)
RK_Slider pitch({
    .label = "Pitch",
    .centering = RK_CENTER,
    .x = 80, .y = 40
});

// 5-position detent slider (snaps to -100, -50, 0, +50, +100)
RK_Slider gear({
    .label = "Gear",
    .detents = 5,
    .x = 120, .y = 40
});

void loop() {
    RadioKit.update();
    int8_t throttlePos = throttle.get();  // -100 to +100
    setMotorSpeed(map(throttlePos, -100, 100, -255, 255));
}
```

---

### Knob

Rotary analog input control (−100 to +100). Identical wire format to `RK_Slider` but rendered as a 270° circular arc knob with a vertical-drag gesture.

Like the Slider, the Knob utilizes the **Spring Simulation Engine** for consistent, premium haptic response when returning to center or snapping to detents.

**Structure:**

```cpp
struct RK_KnobProps {
    const char* label    = nullptr;
    const char* icon     = nullptr; // Shown on knob face
    uint8_t     x = 0, y = 0;
    float       scale    = 1.0f;
    uint8_t     style    = 0;
    //--------------------------
    uint8_t     centering = RK_CENTER_NONE;
    uint8_t     detents   = 0;
    int8_t      value     = 0; // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns position (−100 to +100). |
| `set(int8_t)` | `props.value = val;` | Force update app position (−100..+100). |
| `centering()` | `props.centering` | Returns the centering mode. |
| `detents()` | `props.detents` | Returns the detent count. |

**Examples:**

```cpp
// Panning knob (spring-returns to centre)
RK_Knob pan({
    .label = "Pan",
    .centering = RK_CENTER,
    .x = 100, .y = 60,
    .scale = 2.0f
});

// Volume knob (continuous, 12 o'clock = 0)
RK_Knob vol({
    .label = "Vol",
    .x = 140, .y = 40,
    .icon = "volume-2"
});

// 5-detent EQ knob (-100, -50, 0, +50, +100)
RK_Knob eq({
    .label = "Bass",
    .detents = 5,
    .x = 180, .y = 60
});

void loop() {
    RadioKit.update();
    int8_t panPos = pan.get();
    setPanPosition(panPos);
}
```

---

### Joystick

2-axis analog controller (−100 to +100). 

Interaction is powered by two independent **Spring Simulations** for the X and Y axes, allowing skin creators to define the precise "stiffness" and "bounciness" of the stick return.

**Structure:**

```cpp
struct RK_JoystickProps {
    const char* label = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    bool        enabled = true;
    uint8_t     variant = 0;  // 0=self-centering, 1=no-centering
    //--------------------------
    int8_t      xvalue = 0;   // -100 to +100
    int8_t      yvalue = 0;   // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `getX()` | `props.xvalue` | Returns X-axis (−100 to +100). |
| `getY()` | `props.yvalue` | Returns Y-axis (−100 to +100). |

**Joystick Variants (`variant`):**

| Value | Name | Behavior |
|-------|------|----------|
| `0` | **Self-Centering** | Springs to center for both X,Y (Default). |
| `1` | **No-Centering** | No centering — stays where released. |

**Example:**

```cpp
RK_Joystick drive({
    .x = 180,
    .y = 50,
    .rotation = 90,   // Rotate for vertical layout
    .variant = 1      // No centering (tank-style)
});

void loop() {
    RadioKit.update();
    
    int8_t x = drive.getX();  // Left/Right
    int8_t y = drive.getY();  // Forward/Back
    
    // Differential drive
    int16_t left  = y + x;
    int16_t right = y - x;
    
    setMotorSpeeds(left, right);
}
```

---

### MultipleButton / MultipleSelect

Selection groups (Radio or Checkbox). State is an **8-bit Bitmask** (max 8 items).

> **Skin folders**: `multiple_button/` for button style, `multiple_select/` for select/checkbox style. Assets reside in the respective directories of a skin pack.

**Widget Structure:**

```cpp
struct RK_MultipleProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    //--------------------------
    uint8_t     style = 0;
    uint8_t     variant = 0;   // 0=MultipleButton (radio), 1=MultipleSelect (checkbox)
    uint8_t     value = 0;     // Bitmask (bit 0 = item 0, bit 1 = item 1, etc.)
    std::initializer_list<RK_Item> items = {};
};
```

**Item Structure:**

```cpp
struct RK_Item {
    const char* label = nullptr; // Display text
    const char* icon  = nullptr; // Optional icon name
    uint8_t     pos   = 255;     // Fixed bitmask position (0-7). 255 = auto-assign.
};
```

> **Note:** These widgets use a **Fixed 8-Slot Memory Pool** managed by the class. The `initializer_list` in the struct passes your initial items into this pre-allocated storage (max 8 items).

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns current bitmask (`uint8_t`). |
| `get(index)` | `(props.value & (1 << index))` | Returns `true` if index is active. |
| `clear()` | `props.items = {}; props.value = 0;` | Removes all items. |
| `add(RK_Item)` | (Implicit Pool access) | Adds an item to the pool (Max 8). |
| `remove(index)` | (Implicit Pool access) | Removes an item by index. |
| `setIcon(char*)` | `props.icon = val;` | Updates group heading icon. |

**Example:**

```cpp
RK_MultipleSelect toolbar({
    .label = "Systems",
    .icon = "settings",
    .x = 100, .y = 20,
    .items = {
        { .label = "WiFi",   .icon = "wifi",   .pos = 0 },
        { .label = "BT",     .icon = "bluetooth", .pos = 1 },
        { .label = "GPS",    .icon = "satellite", .pos = 2 }
    }
});

void loop() {
    RadioKit.update();
    
    uint8_t mask = toolbar.get();
    
    if (toolbar.get(0)) {  // WiFi selected (bit 0)
        enableWiFi();
    }
    if (toolbar.get(1)) {  // BT selected (bit 1)
        enableBluetooth();
    }
}
```

---

### LED

Visual status indicator (Arduino → App). 

> **Skin folder**: `led/` – assets for the LED widget live in this directory of a skin pack.

**Structure:**

```cpp
struct RK_LEDProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    //--------------------------
    uint8_t     style = 0;
    bool        state = false;
    uint8_t     red = 255, green = 0, blue = 0;
    uint8_t     opacity = 255;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `on()` | `props.state = true;` | Turns LED ON. |
| `off()` | `props.state = false;` | Turns LED OFF. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon (e.g. `"battery"`). |
| `setColor(uint32_t)` | — | Accepts 6-digit (RGB) or 8-digit (RGBA) hex. |
| `setOpacity(uint8_t)` | `props.opacity = val;` | Sets transparency (0-255). |
| `setRed(uint8_t)` | `props.red = val;` | Sets red component (0-255). |
| `setGreen(uint8_t)` | `props.green = val;` | Sets green component (0-255). |
| `setBlue(uint8_t)` | `props.blue = val;` | Sets blue component (0-255). |

**Example:**

```cpp
RK_LED telemetryOK({
    .x = 10, .y = 10,
    .scale = 1.4f,
    .icon = "check-circle",
    .red = 0, .green = 255, .blue = 0, // Green
    .state = true
});

void loop() {
    RadioKit.update();
    
    if (linkEstablished) {
        telemetryOK.on();
        telemetryOK.setColor(0x00FF00); // Green
    } else {
        telemetryOK.off();
    }
}
```

---

### Text

Dynamic text display label (Arduino → App). Read-only.

> **Skin folder**: `display/` – the read-only text widget uses the `display/` directory in a skin pack.

**Structure:**

```cpp
struct RK_TextProps {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint8_t     x = 0, y = 0;
    int16_t     rotation = 0;
    float       scale = 1.0f;
    float       aspect = 5.0f;   // Width multiplier
    //--------------------------
    uint8_t     style = 0;
    const char* text = nullptr;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `set(const char*)` | `props.text = val;` | Updates text content. |
| `setIcon(char*)` | `props.icon = val;` | Updates prefix icon (e.g. `"terminal"`). |

**Example:**

```cpp
RK_Text status({
    .label = "LOG:",
    .x = 50, .y = 10,
    .icon = "terminal",
    .aspect = 10.0f,  // Extra wide
    .text = "System Ready"
});

void loop() {
    RadioKit.update();
    
    static uint32_t lastUpdate = 0;
    if (millis() - lastUpdate > 1000) {
        lastUpdate = millis();
        
        char buf[32];
        snprintf(buf, sizeof(buf), "Uptime: %lus", 
                 (unsigned long)(millis() / 1000));
        status.set(buf);
    }
}
```

---

## 3. Constants & Enums

### Architecture (`architecture`)

Detected hardware platform (read-only via `RadioKit.config.architecture`):

| Constant | Value | Platform |
|----------|-------|----------|
| `RK_ARCH_UNKNOWN` | 0 | Unknown/Unsupported |
| `RK_ARCH_ESP32` | 1 | ESP32 (NimBLE) |
| `RK_ARCH_NORDIC` | 2 | nRF52/nRF53 series |
| `RK_ARCH_SAMD` | 3 | SAMD21/SAMD51 (Arduino Zero, MKR) |
| `RK_ARCH_STM32` | 4 | STM32 series (Blue Pill, etc.) |

---

### Slider / Knob Centering Modes

Passed as the `centering` field of `RK_SliderProps` / `RK_KnobProps`:

| Constant | Value | Behaviour |
|----------|-------|-----------|
| `RK_CENTER_NONE` | 0 | No spring return — stays where released (default). |
| `RK_CENTER_LEFT` | 1 | Springs to −100 on release. |
| `RK_CENTER` | 2 | Springs to 0 (centre) on release. |
| `RK_CENTER_RIGHT` | 3 | Springs to +100 on release. |

---

### `RK_VARIANT()` Macro

Packs a centering mode and a detent count into the single `variant` byte:

```cpp
// Syntax
RK_VARIANT(centering, detents)
//   centering : RK_CENTER_NONE / LEFT / CENTER / RIGHT
//   detents   : 0 = continuous; 1–63 = number of snap positions

// Examples
RK_VARIANT(RK_CENTER, 0)      // spring-to-centre, continuous
RK_VARIANT(RK_CENTER_NONE, 5) // no spring, 5 snap positions
RK_VARIANT(RK_CENTER, 3)      // spring-to-centre, 3 detents
```

**Note:** When using `RK_SliderProps` or `RK_KnobProps`, you can set `centering` and `detents` directly — the constructor packs them automatically. Use `RK_VARIANT()` only when constructing the raw `variant` byte manually (e.g., for custom widget types).

---

### UI Theme Identifiers

String-based identifiers for UI skins. Pass to `RadioKit.config.theme`:

| Identifier | Description |
|------------|-------------|
| `RK_DEFAULT` | Light blue, modern (default) |
| `RK_DARK` | Dark mode |
| `RK_RETRO` | CRT green phosphor |
| `RK_NEON` | Cyberpunk neon |
| `RK_MINIMAL` | Flat, minimal |
| `"https://..."` | Custom skin pack URL (GitHub raw ZIP) |

**Example:**

```cpp
RadioKit.config.theme = RK_DARK;
// or
RadioKit.config.theme = "https://github.com/user/radiokit-skin/archive/main.zip";
```

---

### Widget Styles

Supported by Buttons, LEDs, and Text:

| Constant | Value | Description |
|----------|-------|-------------|
| `RK_PRIMARY` | 0 | Primary style (default) |
| `RK_DIM` | 1 | Dimmed/inactive |
| `RK_SUCCESS` | 2 | Success state (green) |
| `RK_WARNING` | 3 | Warning state (yellow) |
| `RK_DANGER` | 4 | Danger state (red) |

**Example:**

```cpp
btn.props.style = RK_DANGER;  // Red button
led.props.style = RK_SUCCESS; // Green LED
```

---

### LED Colours

RGB hex values for `setColor()` or individual component setters:

| Name | Hex | Components (R,G,B) |
|------|-----|--------------------|
| `RK_OFF` | `0x000000` | (0, 0, 0) |
| `RK_RED` | `0xFF0000` | (255, 0, 0) |
| `RK_GREEN` | `0x00FF00` | (0, 255, 0) |
| `RK_BLUE` | `0x0000FF` | (0, 0, 255) |
| `RK_YELLOW` | `0xFFFF00` | (255, 255, 0) |

**Example:**

```cpp
led.setColor(RK_GREEN);
// or
led.setRed(0);
led.setGreen(255);
led.setBlue(0);
```

---

## Best Practices

1. **Always call `update()`** — Never block in `loop()` with `delay()` or long computations.
2. **Declare widgets globally** — They self-register on construction.
3. **Configure before `begin()`** — `config` fields are read-only after `begin()`.
4. **Use `pushUpdate()` for programmatic changes** — Keeps the app in sync when firmware modifies widget state.
5. **Keep `loop()` fast** — Defer heavy work to timers or state machines.
6. **Check `isConnected()`** — Before sending critical updates.
7. **Use `centering` and `detents`** — For tactile, physical-feeling controls.
8. **Respect the 8-item limit** — `MultipleButton`/`MultipleSelect` have a fixed pool of 8 slots.

## See Also

- **[Getting Started](setup.md)** — Installation and first sketch
- **[UI Layout](ui_layout.md)** — Coordinate system and sizing details
- **[Protocol Specification](protocol.md)** — Binary packet format details
