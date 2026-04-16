# RadioKit - Controller UI Skins

RadioKit allows users to change the visual aesthetic of the controller interface using **UI Skin Packs**. These packs define colors, fonts, and icons for all widgets without requiring an app update or re-installation.

---

## 1. Skin Types & Resolution

The `RadioKit.config.theme` string tells the app which skin to load. The app resolves this identifier in the following priority:

1.  **Built-in Skins**: Bundled directly with the app as assets in `assets/skins/` (e.g., `"default"`, `"debug"`). These are immutable and always available.
2.  **Sideloaded Skins**: Skins manually imported by the user (stored in app data). Once imported, they are available by their manifest name.

> [!NOTE]
> **GitHub Synchronization** is planned for a future release and is not currently supported.

> [!NOTE]
> If a requested skin is unavailable or fails to download, the app automatically falls back to the `"default"` skin.

---

## 2. Usage (C++ Library)

To apply a skin, set the `theme` field in your `setup()` function.

```cpp
void setup() {
    RadioKit.config.name = "My Device";
    
    // 1. Using a local/built-in skin name
    RadioKit.config.theme = "retro"; 
    
    // 2. OR Using a GitHub URL for a custom skin
    // RadioKit.config.theme = "https://github.com/RadioKit/skin-cyberpunk";
    
    RadioKit.begin();
}
```

---

## 3. Skin Pack Format (.rkskin)

A Skin Pack is a ZIP archive (identifiable by the `.rkskin` extension) containing a manifest and visual assets.

### Directory Structure
```text
skin-pack/
├── manifest.json   # Core styling and metadata
├── preview.png      # Optional preview thumbnail
└── assets/          # Custom SVG/PNG icons
```

### `manifest.json` Schema
The manifest defines **Design Tokens** that map to widget properties.

```json
{
  "name": "Industrial Retro",
  "version": "1.2.0",
  "author": "RadioKit Team",
  "tokens": {
    "colors": {
      "primary": "#FF8C00",
      "background": "#1A1A1A",
      "surface": "#2C2C2E",
      "success": "#34C759",
      "danger": "#FF4B4B"
    },
    "typography": {
      "fontFamily": "Inter", // Uses Google Fonts by name
      "fontWeight": "900"
    },
    "shapes": {
        "borderRadius": 4,
        "borderWidth": 1
    }
  }
}
```

---

## 4. Typography & Google Fonts

RadioKit uses the **Google Fonts** ecosystem for typography. Instead of bundling `.ttf` files inside the skin pack, the manifest simply specifies the font name.

### Implications of Name-Based Loading

- **Dynamic Fetching**: The app will automatically download the required font from Google's servers the first time a skin is applied.
- **Offline Behavior**: If the device is offline and the font has not been previously cached, the app will gracefully fall back to the **Default skin font**.
- **Reduced Bundle Size**: Skin packs (`.rkskin`) remain extremely lightweight (kilobytes instead of megabytes) because they do not contain binary font files.
- **Consistency**: Using the Google Fonts library ensures anti-aliasing and weights are rendered consistently across Android, iOS, and Web.

---

## 5. Installation & Sideloading

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

These skins serve as the **Immutable Baseline**. If the app is launched for the first time or reset, it will always have access to these core aesthetics.

---

## 7. Planned Features

- **GLSL Shaders**: Support for custom vertex/fragment shaders for neon glows and CRT effects.
- **Animation Definitions**: Custom physics and transition curves for interactive widgets.
- **Sound Packs**: Associating specific sounds with widget interactions (clicks, slides).
