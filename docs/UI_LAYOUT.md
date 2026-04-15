# RadioKit UI & Layout

This document describes the coordinate system, scaling model, and visual theme engine used by RadioKit.

---

## 1. Coordinate System

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

## 2. Layout Model — Scale & Aspect

RadioKit uses a **Default Size + Scale + Aspect** model. 

```
height = default_height × scale
width  = height × aspect
```

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
    RadioKit.config.password = "1234"; // Optional security
    RadioKit.config.theme = RK_FUTURISTIC; // Global theme
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

## 4. Themes & Icons

RadioKit delegates complex rendering to the mobile application. This "Lean" approach allows for premium visuals without taxing the Arduino's RAM.

### Global Themes
Setting `RadioKit.config.theme` changes the aesthetic of the entire interface (e.g., modern dark mode vs. retro industrial).

### Semantic Styles
Use the `style` field to define the **purpose** of a widget. The app automatically maps these to theme-appropriate color palettes (Success, Warning, Danger, etc.).

### Icon Engine
Icons are passed as simple strings. Using standard names ensures compatibility across all app-side icon packs:
- Inputs: `"power"`, `"wifi"`, `"settings"`.
- Actions: `"flame"`, `"target"`, `"camera"`.

> [!TIP]
> **Implementation Details**: To apply these layout and visual principles in code, see the **[Common Variables](file:///home/sun/Apps/RadioKit/docs/FUNCTIONS.md#common-variables)** and **[Widget Reference](file:///home/sun/Apps/RadioKit/docs/FUNCTIONS.md#4-widget-class-reference)** in the Functions documentation.

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