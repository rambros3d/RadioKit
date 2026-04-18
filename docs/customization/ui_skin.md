# RadioKit - Controller UI Skins

RadioKit uses Skins to define style of the **Controller UI**. These packs define images (svg, jpeg, png), colors, fonts, and icons for all widgets.

A Skin Pack is a ZIP archive (The RadioKit Skin is identifiable by the `.rkskin` extension) containing a manifest and visual assets.

Note: The Skin theme is not to be confused with the app theme.

---

## 1. Skin Sources

The `RadioKit.config.theme` string tells the app which skin to load. The app resolves this identifier in the following priority:

1.  **Built-in Skins**: Bundled directly with the app as assets in `assets/skins/` (e.g., `"default"`, `"debug"`). These are immutable and always available.
2.  **Downloaded Skins**: Skins manually downloaded by the user (stored in app data). Once imported, they are available by their manifest name.

> [!NOTE]
> **GitHub Synchronization** is planned for a future release and is not currently implemented.
> If a requested skin is unavailable or fails to download, the app automatically falls back to the `"default"` skin.

## 2. Usage (C++ Library)

To apply a skin, set the `theme` field in your `setup()` function. The firmware cannot edit specific skin attributes; it only selects the "Vibe".

```cpp
void setup() {
    RadioKit.config.name = "My Device";
    
    // 1. Using a local/built-in skin name
    RadioKit.config.theme = "default"; 
    
    // 2. OR Using a GitHub URL for a custom skin (Planned)
    // - RadioKit.config.theme = "https://github.com/RadioKit/radiokit-skins-cyberpunk";
    // - RadioKit.config.theme = "https://github.com/rambros3d/radiokit-skins/retro";
    
    RadioKit.begin();
}
```

---

## 3. Semantic Styles (Dynamic Theming)

While the firmware cannot send raw HEX colors, it **can** influence the appearance using `setStyle(uint8_t styleIndex)`. 

In a **Version 1.5** manifest, skins can optionally redefine what these styles mean visually. This allows the same "Danger" style (index 4) to be a glowing red neon in one skin and a matte orange stripe in another.

---

## 4. Skin Pack Format (.rkskin)

A Skin Pack is a ZIP archive containing a manifest and visual assets.

### Directory Structure
```text
(skin-pack-name)/
├── manifest.json        # Core styling and metadata
├── global/              # App-wide assets (backgrounds, overlays)
├── sounds/              # Shared audio assets (wav, mp3, ogg)
│   └── background.jpg   # Main controller backdrop
├── button_push/         # Momentary push buttons
│   ├── bg.svg
│   ├── active.svg
│   └── config.json      # Scale/Press animations
├── button_toggle/       # Toggle switches and buttons
│   ├── on.svg
│   ├── off.svg
│   └── config.json      # Color fade, distinct on/off haptics
├── switch/              # SlideSwitch components
│   ├── track.svg
│   ├── thumb.svg
│   └── config.json      # Slide physics
├── slider/              # Sliders and Knobs
│   ├── track.svg
│   ├── thumb.svg
│   └── config.json      # Detent snapping, spring return
├── joystick/            # Joystick components
│   ├── base.svg
│   ├── stick.svg
│   └── config.json      # Friction and deadzones
├── led/                 # LED components
│   ├── base.svg
│   ├── glow.png
│   └── config.json      # Pulse speed, glow intensity
├── multiple_button/     # Single-selection (Radio) group
│   ├── bg.svg
│   ├── item.svg
│   └── config.json      # Slide indicator transitions
└── multiple_select/     # Multi-selection (Bitmask) group
    ├── bg.svg
    ├── item.svg
    └── config.json      # Independent fade/check transitions
```

### `manifest.json` Schema (v1.5)

The v1.5 manifest introduces **Semantic Theming**. This allows the UI to stay consistent even when switching between "Neon" and "Retro" skins.

```json
{
  "name": "Neon Midnight",
  "version": "1.5.0",
  "author": "RadioKit Team",
  "tokens": {
    "colors": {
      "primary": "#39FF14",    // Brand/Action color
      "onPrimary": "#000000",  // Text on top of primary
      "background": "#000000", // Main app canvas
      "surface": "#111111",    // Widget containers
      "onSurface": "#FFFFFF",  // Default text
      "outline": "#333333"     // Borders and dividers
    },
    "effects": {
      "glassOpacity": 0.2,     // 0.0 to 1.0 (requires background.jpg)
      "glassBlur": 20.0,       // Backdrop blur sigma
      "glowIntensity": 0.8     // Bloom intensity for active widgets
    },
    "typography": {
      "fontFamily": "VT323",   // Loaded via coollabs fonts
      "fontWeight": "400",
      "letterSpacing": 1.2
    },
    "shapes": {
      "borderRadius": 0.0,     // 0 for sharp, >20 for pill
      "borderWidth": 2.0
    },
    "styles": {
      "0": { "primary": "#39FF14", "glow": true },  // RK_PRIMARY
      "1": { "primary": "#555555", "glow": false }, // RK_DIM
      "2": { "primary": "#39FF14", "glow": true },  // RK_SUCCESS
      "3": { "primary": "#FFEA00", "glow": true },  // RK_WARNING
      "4": { "primary": "#FF073A", "glow": true }   // RK_DANGER
    }
  }
}
```

#### Key v1.5 Concepts:

- **Style Overrides**: The `styles` map allows the firmware's `setStyle(index)` command to trigger specific color and effect sets defined in the skin.
- **Glassmorphism**: If `glassOpacity` is set, widgets will render with a semi-transparent blurred background, provided a `global/background.jpg` is present.
- **Coollabs Fonts**: All `fontFamily` names are automatically resolved against the privacy-friendly coollabs fonts repository.

### Advanced Widget Configurations (`config.json`)

Each widget folder can contain a `config.json` to fine-tune its interactive feel. Below is the comprehensive schema for v1.5.

```json
{
  "animations": {
    "press": {
      "duration_ms": 100,
      "curve": "easeOutCubic",
      "scale": 0.95,
      "opacity": 1.0
    },
    "release": {
      "duration_ms": 400,
      "curve": "elasticOut",
      "scale": 1.0
    },
    "hover": {
      "duration_ms": 200,
      "curve": "linear",
      "glow_boost": 0.2
    }
  },
  "physics": {
    "damping": 0.7,      // For sliders and joysticks (0.0 - 1.0)
    "stiffness": 100.0,   // Spring stiffness for return-to-center
    "mass": 1.0,         // Inertia for scrolling/sliding
    "detents": "soft"    // "none", "soft", or "hard" snapping
  },
  "haptics": {
    "on_press": "medium",
    "on_release": "light",
    "on_change": "selection"
  },
  "audio": {
    "press_sample": "click.mp3",
    "release_sample": "clack.mp3",
    "volume": 0.5
  }
}
```

### Mixed-Mode Discovery (v1.6)

RadioKit Skins are **Hybrid**. You can mix and match rendering technologies within a single `.rkskin` pack. The app chooses the renderer for each widget based on the files present in its directory.

| File Present | Renderer Used | Ideal For... |
| :--- | :--- | :--- |
| `widget.html` | **HTML/CSS (Native)** | Text-rich labels, complex lists, data tables. |
| `bg.svg` / `thumb.svg` | **Native (Skia/Impeller)** | Joysticks, Sliders, mechanical buttons (Best performance). |
| `config.json` | **Behavioral** | Defines haptics and physics regardless of the visual renderer. |

#### Resolver Logic:
The skin engine follows this priority when building a widget:
1.  **HTML Override**: If `widget.html` exists in the widget folder, use the HTML engine.
2.  **Asset Mapping**: If SVGs/PNGs exist, use the native vector renderer.
3.  **Default Fallback**: If the folder is empty or missing, fall back to the **Default Skin**.

---

## 4. Typography & Google Fonts

RadioKit uses the **Google Fonts** ecosystem for typography. Instead of bundling `.ttf` files inside the skin pack, the manifest simply specifies the font name.

> [!NOTE]
> The App uses https://github.com/coollabsio/fonts to load fonts, A privacy-friendly drop-in replacement for Google Fonts.

### Implications of Name-Based Loading

- **Dynamic Fetching**: The app will automatically download the required font from Google's servers the first time a skin is applied.
- **Offline Behavior**: If the device is offline and the font has not been previously cached, the app will gracefully fall back to the **Default skin font**.
- **Consistency**: Using the Google Fonts library ensures anti-aliasing and weights are rendered consistently across Android, iOS, and Web.

---

## 5. Installation

### Manual Import (Sideloading)
1. Prepare a `.rkskin` (ZIP) file containing your skin assets.
2. In the RadioKit App, navigate to **Settings > Skins**.
3. Tap **Import Skin** and select your file.
4. The skin is now "Installed" and can be requested by the hardware using the `name` defined in the manifest.

---

## 5. GitHub Sync (Planned)

Automatic synchronization from GitHub repositories is planned for a future update. For now, users should download `.rkskin` files and import them manually via the Sideloading interface.

---

## 6. Built-in Skins & Distribution
 
Default skins are included in the app's root bundle. They follow the same directory structure as custom skins but are located in the `assets/skins/` folder of the Flutter project.

### Registry in `pubspec.yaml`
```yaml
flutter:
  assets:
    - assets/skins/default/manifest.json
    - assets/skins/retro/manifest.json
```

These skins serve as the **Immutable Baseline**. If the app is launched for the first time or reset, it will always uses this skin.

---

## 7. Planned Features (TBD)

- **GLSL Shaders**: Support for custom vertex/fragment shaders for neon glows and CRT effects.
- **Animation Definitions**: Custom physics and transition curves for interactive widgets.
- **Sound Packs**: Associating specific sounds with widget interactions (clicks, slides).
- **Haptic Feedback Profiles**: Custom vibration patterns for mobile devices.
