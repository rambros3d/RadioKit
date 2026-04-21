# RadioKit - Controller UI Skins (v1.7)

RadioKit v1.7 introduces **Independent Width & Height Scaling** for supported widgets, while maintaining a high-fidelity native vector engine for all skin packs.

## 1. Dimensional Scaling
Starting with v1.7, the layout engine strictly separates width and height multipliers to provide more intuitive control over the dashboard layout:

- **Variable Scaling**: Slider and Text widgets allow independent `width` and `height` factors.
- **Dynamic Aspect**: `MultipleButton` and `MultipleSelect` widgets automatically calculate their width based on the number of items (`1 : N`), scaled by the `height` factor.
- **Fixed Scaling**: All other widgets (Joystick, Knob, LED, Button, Switch) are scaled using a single `height` factor to preserve their natural shapes.

## 1. Pure Native Architecture

RadioKit skins now exclusively use Skia/Impeller-based rendering. Widgets are composed of high-quality SVG layers that are tinted and transformed in real-time.

### Key Shifts in v1.6:
- **No HTML/CSS**: The legacy mixed-mode architecture is gone. All widgets are now pure native components.
- **Decentralized Config**: The centralized `manifest.json` no longer manages widget associations. Each widget is now a self-contained folder in the skin pack.
- **Physics Simulator**: Animations are now driven by a high-fidelity **Spring Simulation** engine, rather than rigid cubic-bezier curves.

---

## 2. Directory Structure (.rkskin)

A Skin Pack is a ZIP archive (identifiable by the `.rkskin` extension). To add support for a widget, simply create a folder with the widget's name in the root of the pack.

```text
(skin-pack-name)/
├── manifest.json        # Global tokens and metadata
├── global/              # Shared assets (backgrounds, overlays)
├── button_push/         # Folder for RK_PushButton
│   ├── bg.svg
│   ├── active.svg       # Shown when pressed
│   └── config.json      # Mapping and local animations
├── slider/              # Folder for RK_Slider
│   ├── track.svg
│   ├── thumb.svg
│   └── config.json      # Physics parameters (damping, stiffness)
└── joystick/            # Folder for RK_Joystick
    ├── base.svg
    ├── stick.svg
    └── config.json      # Deadzones and spring-return feel
```

---

## 3. Global Manifest (`manifest.json`)

The manifest now focuses purely on identity and visual tokens.

```json
{
  "name": "Neon Midnight",
  "version": "1.6.0",
  "author": "RadioKit Team",
  "tokens": {
    "colors": {
      "primary": "#39FF14",
      "onPrimary": "#000000",
      "background": "#000000",
      "surface": "#111111",
      "onSurface": "#FFFFFF"
    },
    "typography": {
      "fontFamily": "Inter"
    }
  }
}
```

---

## 4. Widget Configuration (`config.json`)

Each widget folder contains a `config.json` that defines its specific visual mapping and physical behavior.

### High-Fidelity Physics
RadioKit v1.6 uses a **Spring Simulation** for interactive elements like Joysticks, Sliders, and Knobs.

```json
{
  "layers": {
    "track": "track.svg",
    "thumb": "thumb.svg"
  },
  "physics": {
    "damping": 0.5,      // Damping ratio (0.1 to 1.0)
    "stiffness": 100.0,   // Spring stiffness (lower = softer)
    "mass": 1.0,         // Inertia of the component
    "deadzone": 0.05      // Center deadzone (%)
  }
}
```

> [!NOTE]
> **Hardware Precedence**: Functional behavior (like self-centering) is defined by the hardware's `variant` byte. The `config.json` parameters purely define the **aesthetic character** of that behavior.

---

## 5. Real-time Reactivity

The RadioKit dashboard supports **instant theme switching**. When a user selects a new skin in the Gallery, the app:
1. Re-resolves all active widgets against the new skin folders.
2. Injects the new `SpringSimulation` parameters into the active animation controllers.
3. Swaps the SVG layers immediately without re-rendering the entire dashboard.

---

## 6. Installation & Gallery

Skins can be imported manually using the `.rkskin` importer in the settings menu, or browsed in the **Theme Gallery** (Palette icon in the Control Screen).

## 7. Planned Features (TBD)

- **GLSL Shaders**: Support for custom vertex/fragment shaders for neon glows and CRT effects.
- **Sound Packs**: Associating specific sounds with widget interactions (clicks, slides).
- **Haptic Feedback Profiles**: Custom vibration patterns for mobile devices.
