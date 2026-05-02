# RadioKit UI & Layout

This document describes the coordinate system, scaling model, and visual theme engine used by RadioKit v2.0.

---

## 1. Coordinate System

RadioKit uses a virtual coordinate system which is independent of the actual screen size of the device. The default canvas size is 200×200 (landscape) or 200×200 (portrait — same virtual space, rotated).

```
(0,200) ┌──────────────────────────┐ (200,200)
         │                          │
         │  Coord system (0-200)    │
         │                          │
   (0,0) └──────────────────────────┘ (200,0)
```

- **Origin**: `(0,0)` is the **bottom-left** corner.
- **Anchor**: `x`, `y` coordinates refer to the **center** of the widget.
- **Canvas Range**: `0`–`200` on both axes. Values outside this range are clamped.
- **Rotation**: `0`–`360` degrees. Positive is **clockwise**.

---

## 2. Layout Model

RadioKit uses a **Baseline × Scale** model. Each widget has a baseline size (at `scale = 1.0`), and the final size is computed by multiplying by the scale factor.

### Size Calculation

```
finalHeight = baseHeight × scale
finalWidth  = (baseHeight × aspect) × scale
```

- **`scale`** — Controls overall size (default `1.0`).
- **`aspect`** — Controls width relative to height (default varies by widget type).
  - Slider: `aspect = 5.0` (5× wider than tall)
  - Button: `aspect = 1.0` (square)
  - Knob: `aspect = 1.0` (circular)

### Example

```cpp
RK_Slider slider({
    .label = "Throttle",
    .x = 100, .y = 50,
    .scale = 1.5f,    // 1.5× taller
    .aspect = 8.0f    // 8× wider than tall
});
```

Result: A wide, tall slider.

---

## 3. Widget Positioning

All widgets share these common parameters in their `Props` struct:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `x`, `y` | `uint8` | Center position (0–200) | 100, 100 |
| `scale` | `float` | Size multiplier | 1.0 |
| `rotation` | `int16` | Rotation in degrees (clockwise) | 0 |
| `label` | `const char*` | Text label above widget | `nullptr` |
| `icon` | `const char*` | Icon name from skin | `nullptr` |
| `style` | `uint8` | Visual style (0–4) | 0 |

### Coordinate Examples

```cpp
// Top-left corner
RK_Button btn1({.x = 20, .y = 180, .label = "TL"});

// Center
RK_Button btn2({.x = 100, .y = 100, .label = "Center"});

// Bottom-right
RK_Button btn3({.x = 180, .y = 20, .label = "BR"});
```

---

## 4. Orientation & Canvas Size

Layout settings are managed through `RadioKit.config` in `setup()`.

### Configuration

```cpp
void setup() {
  RadioKit.config.name = "MyRobot";
  RadioKit.config.description = "Robot Controller";
  RadioKit.config.theme = RK_DEFAULT;
  RadioKit.config.orientation = RK_LANDSCAPE;  // or RK_PORTRAIT
  RadioKit.config.width = 200;   // 0 = auto (default)
  RadioKit.config.height = 200;  // 0 = auto (default)
  
  RadioKit.begin();
  RadioKit.startBLE("MyRobot");
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `orientation` | `RK_LANDSCAPE` | `RK_LANDSCAPE` or `RK_PORTRAIT` (affects default aspect) |
| `width` | `0` (auto) | Canvas width in virtual units (0–200) |
| `height` | `0` (auto) | Canvas height in virtual units (0–200) |

**Note:** Setting `width` and `height` to `0` enables auto-sizing based on widget positions.

---

## 5. Visual Styling

### Themes

Set via `RadioKit.config.theme`:

| Theme | Description |
|-------|-------------|
| `RK_DEFAULT` | Light blue, modern (default) |
| `RK_DARK` | Dark mode |
| `RK_RETRO` | CRT green phosphor |
| `RK_NEON` | Cyberpunk neon |
| `RK_MINIMAL` | Flat, minimal |
| `"custom-url"` | Custom skin from GitHub |

### Widget Styles

The `style` parameter applies semantic meaning, mapped to theme colors:

| Style | Constant | Use Case |
|-------|----------|----------|
| `0` | `RK_PRIMARY` | Primary action (default) |
| `1` | `RK_DIM` | Inactive/secondary |
| `2` | `RK_SUCCESS` | Positive state (green) |
| `3` | `RK_WARNING` | Warning state (yellow) |
| `4` | `RK_DANGER` | Danger state (red) |

**Example:**

```cpp
RK_PushButton fire({
    .label = "FIRE",
    .x = 20, .y = 60,
    .style = RK_DANGER,  // Red button
    .icon = "flame"
});
```

---

## 6. Icons

Icons are referenced by string name. Standard names ensure cross-theme compatibility:

| Category | Icons |
|----------|-------|
| **Power** | `"power"`, `"power-off"`, `"battery"` |
| **Connectivity** | `"wifi"`, `"bluetooth"`, `"usb"`, `"antenna"` |
| **Actions** | `"play"`, `"pause"`, `"stop"`, `"record"` |
| **Sensors** | `"temperature"`, `"pressure"`, `"gyro"` |
| **Navigation** | `"arrow-up"`, `"arrow-down"`, `"home"` |
| **Generic** | `"settings"`, `"menu"`, `"info"`, `"warning"` |

**Example:**

```cpp
RK_Button btn({
    .label = "WiFi",
    .icon = "wifi",
    .x = 50, .y = 50
});
```

---

## 7. Runtime Mutators

Widgets can be modified at runtime via their `props` interface:

```cpp
void loop() {
  RadioKit.update();
  
  // Change label dynamically
  status.props.label = "ALERT!";
  RadioKit.pushMetaUpdate(status.widgetId);
  
  // Change position
  slider.props.x = newX;
  slider.props.y = newY;
  
  // Change style
  led.props.style = RK_SUCCESS;
  
  // Update value
  slider.props.value = 50;
  RadioKit.pushUpdate(slider.widgetId);
}
```

### Available Mutators

| Method | Description |
|--------|-------------|
| `widget.props.label = "..."` | Update label text |
| `widget.props.icon = "..."` | Update icon name |
| `widget.props.x/y` | Update position |
| `widget.props.scale` | Update size |
| `widget.props.rotation` | Update rotation |
| `widget.props.style` | Update visual style |
| `widget.props.value` | Update current value |

---

## 8. Best Practices

1. **Use consistent spacing** — Maintain 10–20 unit gaps between widgets.
2. **Group related controls** — Place related widgets near each other.
3. **Respect safe zones** — Keep critical controls away from edges (10–20 unit margin).
4. **Use appropriate scale** — Buttons: 1.5–2.0×, Sliders: 1.0–1.5×.
5. **Leverage aspect ratio** — Make sliders wide, knobs square.
6. **Use semantic styles** — Apply `RK_SUCCESS`, `RK_DANGER` appropriately.
7. **Test on different screens** — Virtual coordinates ensure consistency.

## See Also

- **[Widgets Reference](widgets.md)** — Complete widget API
- **[Protocol Specification](protocol.md)** — Binary packet format
- **[Getting Started](setup.md)** — Installation and first sketch