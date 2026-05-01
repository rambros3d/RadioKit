# RadioKit Documentation

**Control your Arduino from a smartphone app**

RadioKit is an open-source alternative to RemoteXY. It allows you to build Amazing UI for your Arduino projects using a simple C++ API.

## Features

- **Pure Arduino**: Define your UI in Arduino code.
- **Multiple Transports**: BLE and Serial. More coming soon.
- **Pure Native V1.6 Engine**: Extremely smooth SVG-based rendering with zero HTML overhead.
- **Haptic Physics**: High-fidelity spring simulations for sliders and joysticks.
- **Theme Gallery**: Explore and apply skins in real-time within the app.
- **Cross-Platform**: Client app runs on Android, and Web (Chromium based).

---

## 🚀 Quick Start

### 1. Arduino Setup
Install the library and define your widgets.

```cpp
#include <RadioKit.h>

// Widget declarations
RK_PushButton fireBtn({.label="Fire", .x=20, .y=50, .scale=1.5, .icon="flame"});
RK_ToggleButton power({.label="Power", .x=20, .y=80, .scale=1.5});
RK_Slider slider({.label="Level", .x=100, .y=60, .aspect=8.0f, .value=0});
RK_Knob pan({.label="Pan", .x=170, .y=40, .scale=2.0f, .centering=RK_CENTER});
RK_Joystick joy({.label="Stick", .x=160, .y=70, .scale=2.0f});
RK_LED status({.label="Status", .x=20, .y=20, .scale=1.4f});
RK_Text uptime({.label="Uptime", .x=20, .y=10});

void setup() {
  RadioKit.config.name = "MyRobot";
  RadioKit.config.description = "Robot Controller";
  RadioKit.config.theme = RK_DEFAULT;
  RadioKit.begin();
  RadioKit.startBLE("MyRobot");  // or startSerial(Serial)
}

void loop() {
  RadioKit.update();
  
  // Read widget states
  if (fireBtn.isPressed()) { /* fire! */ }
  if (power.get()) { /* power on */ }
  
  // Update outputs
  int8_t panVal = pan.get();
  uptime.set(String(millis()/1000).c_str());
}
```

### 2. Connect
Open the RadioKit app, scan, and connect. The UI will appear instantly.

---

## 📖 Dive Deeper

### Arduino Library
- **[Getting Started](arduino/setup.md)**: How to set up the RadioKit library.
- **[Widgets Reference](arduino/widgets.md)**: Every widget and its configuration.
- **[UI Layout](arduino/ui_layout.md)**: How the coordinate system and layout works.
- **[Protocol Specification](arduino/protocol.md)**: Details on the binary packet format.

### Flutter Widget Library
- **[Overview](flutter-library/README.md)**: Use RadioKit-style widgets in your own Flutter apps.
- **[Widget API](flutter-library/rk_button.md)**: Full API reference for all widgets.

---

## 🎨 Widget Types

| Widget    | Direction | Description                              |
|-----------|-----------|------------------------------------------|
| Button    | Input     | Momentary press — value 1 while held     |
| Toggle    | Input     | Latching on/off switch                   |
| SlideSwitch | Input   | iOS-style slide toggle                   |
| Slider    | Input     | Linear 0–100 with value label            |
| Knob      | Input     | Rotary 0–100 with spring-centering       |
| Joystick  | Input     | 2-axis draggable, springs to center      |
| LED       | Output    | Colour indicator (off/red/green/blue/yellow) |
| Text      | Output    | Read-only string display                 |
| MultipleButton | Input | Radio-style button group (bitmask)     |
| MultipleSelect | Input | Checkbox group (bitmask)               |

---

## 🏗️ Architecture

### Arduino Library (v2.0)
- Object-oriented widget API with tailored structs
- Zero dynamic allocation — all widgets use static pools
- Reliable packet delivery with sequence tracking
- Supports ESP32 (NimBLE), Nordic nRF52, STM32, SAMD
- Both BLE and Serial transports

### Flutter Widget Library
- Pure Flutter, no platform code
- RadioKit design tokens (colors, typography, shadows)
- Spring physics for premium feel
- Haptic feedback support
- SVG-based rendering

---

## 📦 Project Structure

```
RadioKit/
├── arduino-library/          # Arduino library (v2.0)
│   ├── src/
│   │   ├── RadioKit.h        # Main entry point
│   │   ├── RadioKitConfig.h  # Configuration
│   │   ├── RadioKitProtocol.h# Protocol definitions
│   │   ├── widgets/          # All widget implementations
│   │   └── connection/       # BLE & Serial transports
│   └── examples/             # Example sketches
│
├── flutter-library/          # Flutter widget library
│   ├── lib/
│   │   ├── radiokit_widgets.dart
│   │   └── src/widgets/      # All widget implementations
│   └── example/              # Example app
│
├── flutter-app/              # Reference Flutter app
│   ├── lib/                  # App source
│   └── pubspec.yaml
│
└── docs/                     # This documentation
```

---

## 🔧 Development

### Arduino Library
See [library.json](https://github.com/rambros3d/RadioKit/blob/main/arduino-library/library.json) for dependencies.

### Flutter App
See [pubspec.yaml](https://github.com/rambros3d/RadioKit/blob/main/flutter-app/pubspec.yaml) for dependencies.

---

## 📄 License

MIT — see [LICENSE](../LICENSE) files in each repository.