# RadioKit UI & Layout

This document describes the coordinate system, scaling model, and visual theme engine used by RadioKit.

---

## 1. Coordinate System

RadioKit uses a virtual coordinate system which is independent of the actual screen size of the device. The default canvas size is 200x100 for landscape and 100x200 for portrait.

```
(0, RK_HEIGHT) ┌──────────────────────────┐ (RK_WIDTH, RK_HEIGHT)
               │                          │
               │  Coord system (0-250)    │
               │                          │
         (0,0) └──────────────────────────┘ (RK_WIDTH, 0)
```

- **Origin**: `(0,0)` is the bottom-left corner.
- **Anchor**: `x`, `y` coordinates refer to the **center** of the widget.
- **Canvas Range**: `0`–`250` on both axes. Values set higher are clamped to 250.
- **Rotation**: $0\dots 360$ degrees. Positive is **clockwise**.

---

## 2. Layout Model

RadioKit uses a **Default Size + Scale + Aspect** model. Each widget has a default size, which can be scaled and have its aspect ratio changed. Using a scale factor of 1.0 and an aspect ratio of 1.0 will result in the default size and aspect ratio of the widget. Likewise, n aspect ratio of 0.5 will result in a widget that is twice as tall and half as wide as the default size and aspect ratio.

```
height = base_height × scale_height
width  = (base_height × aspect) × scale_height × extra_width_scale
```

*For fixed-aspect widgets, `scale_width` is locked to `scale_height` and `base_width` is derived as `base_height × aspect`.*

| Float (User) | Wire Encoding | Result |
| ------------ | -------------- | -------------- |
| 1.0          | 10             | 1.0× (Default) |
| 2.5          | 25             | 2.5×           |

---

## 3. Orientation & Dimensions

Layout settings are managed through the global `RadioKit.config` object in `setup()`.

### Setup Example
```cpp
void setup() {
    RadioKit.config.name = "B-52 Stratofort";
    RadioKit.config.password = "1234"; // Optional security password to prevent accidental connections
    RadioKit.config.theme = "futuristic"; // Controller skin
    RadioKit.config.orientation = RK_LANDSCAPE;
    
    RadioKit.begin();
}
```

| Parameter | Default | description |
|---|---|---|
| `orientation` | `RK_LANDSCAPE` | `RK_LANDSCAPE` (200x100) or `RK_PORTRAIT` (100x200). |
| `width`       | `200` | Custom canvas width (0-250). |
| `height`      | `100` | Custom canvas height (0-250). |

---

## 4. Skins & Icons

RadioKit delegates complex rendering to the mobile application. So Arduino only needs to send the widget data and the mobile app will render the widget.

### Controller UI Skins

Setting `RadioKit.config.theme` changes the aesthetic of the entire controller interface. RadioKit supports built-in skins, sideloaded packs, and automatic GitHub synchronization.

**Resolution Priority:**
1.  Built-in (e.g., `"default"`, `"debug"`)
2.  Sideloaded/Local Library (e.g., `"custom-gold"`)

> [!TIP]
> For a full list of available skins and instructions on creating custom skin packs, see the **[UI Skins Documentation](ui_skin.md)**.

### Semantic Styles
Use the `style` field to define the **purpose** of a widget. The app automatically maps these to theme-appropriate color palettes (Success, Warning, Danger, etc.).

### Icon Engine
Icons are passed as simple strings. Using standard names ensures compatibility across all app-side icon packs:
- Inputs: `"power"`, `"wifi"`, `"settings"`.
- Actions: `"flame"`, `"target"`, `"camera"`.

> [!TIP]
> **Implementation Details**: To apply these layout and visual principles in code, see the **[Common Variables](widgets.md#common-variables)** and **[Widget Reference](widgets.md#2-widget-class-reference)** in the Functions documentation.

---

## 5. Mutator Methods (Runtime)

Use these methods to update widgets dynamically during the `loop()`.

### `setPosition()`
```cpp
void setPosition(uint8_t x, uint8_t y);
void setPosition(uint8_t x, uint8_t y, int16_t rotation);
```

### `setScale()`
```cpp
void setScale(float scale);
void setScale(float scale, float aspectRatio);
```

### `setIcon()` / `setStyle()`
```cpp
void setIcon(const char* iconName);
void setStyle(uint8_t styleIndex);
```

### `enable()` / `disable()`
Disabled widgets are hidden across the system and **excluded from protocol traffic** to save bandwidth.