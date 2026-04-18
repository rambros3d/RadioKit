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
    RadioKit.config.theme = "retro"; 
    
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
├── global/              # App-wide assets
│   └── background.jpg   # Main controller backdrop
├── button/              # Push and Toggle buttons
│   ├── bg.svg
│   └── active.svg
├── switch/              # Switch and SlideSwitch components
│   ├── on.svg
│   └── off.svg
├── slider/              # Sliders and Knobs
│   ├── track.svg
│   └── thumb.svg
├── joystick/            # Joystick components
│   ├── base.svg
│   └── stick.svg
├── led/                 # LED components
│   ├── base.svg
│   └── glow.png
└── multiple/            # MultipleButton/Select components
    ├── bg.svg
    └── item.svg
```

### `manifest.json` Schema (v1.5)
The manifest defines **Design Tokens**. New in v1.5 is the `styles` map, which allows per-style overrides of global colors.

```json
{
  "name": "Industrial Retro",
  "version": "1.5.0",
  "author": "RadioKit Team",
  "tokens": {
    "colors": {
      "primary": "#FF8C00",
      "background": "#1A1A1A",
      "surface": "#2C2C2E"
    },
    "effects": {
      "glassOpacity": 0.3,
      "glassBlur": 15.0
    },
    "styles": {
       "0": { "primary": "#FF8C00" }, // RK_PRIMARY
       "4": { "danger": "#FF4B4B", "glow": true } // RK_DANGER
    },
    "typography": {
      "fontFamily": "Inter",
      "fontWeight": "900"
    },
    "shapes": {
        "borderRadius": 12,
        "borderWidth": 1.5
    }
  }
}
```

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
