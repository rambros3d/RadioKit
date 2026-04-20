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

RadioKit_Switch sw;

void setup() {
  RadioKit.addWidget(sw, "Motor", 100, 50, 300, 100);
  RadioKit.begin("MyRobot");
}

void loop() {
  RadioKit.handle();
  // sw.isOn() returns the current state
}
```

### 2. Connect
Open the RadioKit app, scan, and connect. The UI will appear instantly.

---

## 📖 Dive Deeper

Use the sidebar to explore technical details:

- **[API Reference](FUNCTIONS.md)**: Every class and method documented.
- **[UI Layout](UI_LAYOUT.md)**: How the coordinate system and layout works.
- **[Binary Protocol](PROTOCOL.md)**: For those interested in the wire format.
- **[Skins & Themes](UI_SKINS.md)**: Personalize the look of your controllers.
