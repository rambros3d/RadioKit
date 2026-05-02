# RadioKit

Open source alternative to RemoteXY — build amazing UIs for your Arduino projects using a simple C++ API and a native Flutter companion app.

## Overview

RadioKit lets you define your UI directly in Arduino code and see it instantly in a smartphone app. No server, no code generation, just BLE or Serial communication.

### Features

- **Pure Arduino**: Define your UI in Arduino code with a clean object-oriented API
- **Multiple Transports**: BLE (NimBLE) and Serial (USB/UART) support
- **Native V2.0 Engine**: Smooth SVG-based rendering with zero HTML overhead
- **Haptic Physics**: High-fidelity spring simulations for sliders and knobs
- **Theme Gallery**: Multiple built-in skins (default, dark, retro, cyberpunk, neon, minimal)
- **Cross-Platform**: Flutter-based client app runs on Android, iOS, and Web

### Quick Start

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

### Project Structure

```
RadioKit/
├── arduino-library/          # Arduino library (v2.0)
│   ├── src/                   # Core library headers & implementation
│   │   ├── RadioKit.h         # Main entry point
│   │   ├── RadioKitConfig.h   # Configuration & constants
│   │   ├── RadioKitProtocol.h # Protocol v3 definitions
│   │   ├── widgets/           # All widget implementations
│   │   └── connection/        # BLE & Serial transports
│   └── examples/              # Example sketches
│
├── flutter-library/           # Flutter widget library
│   ├── lib/                   # Widget implementations
│   └── example/               # Example app
│
├── flutter-app/               # Reference Flutter companion app
│   ├── lib/                   # App source
│   └── pubspec.yaml
│
└── docs/                      # Documentation
```

### Documentation

- **[Arduino Library](arduino/setup.md)** — Setup, API reference, and examples
- **[Widgets Reference](arduino/widgets.md)** — Complete widget API
- **[UI Layout](arduino/ui_layout.md)** — Coordinate system and sizing
- **[Protocol Spec](arduino/protocol.md)** — Binary packet format details
- **[Flutter Library](flutter-library/README.md)** — Flutter widget API

### Development

- **Arduino Library**: See [library.json](https://github.com/rambros3d/RadioKit/blob/main/arduino-library/library.json) for dependencies
- **Flutter App**: See [pubspec.yaml](https://github.com/rambros3d/RadioKit/blob/main/flutter-app/pubspec.yaml) for dependencies

### License

MIT — see [LICENSE](../LICENSE) files in each repository.