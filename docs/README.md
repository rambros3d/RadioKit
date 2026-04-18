# RadioKit Documentation

**Control your Arduino from a smartphone — no server, no code generation, just BLE.**

RadioKit is an open-source alternative to RemoteXY. It allows you to build sophisticated mobile interfaces for your Arduino projects using a simple C++ API.

## Features

- **No Code Generation**: Your Arduino defines the UI dynamically.
- **Pure BLE**: Works offline, no internet or accounts required.
- **Cross-Platform**: Client app runs on Android, iOS, and Web (Chrome).
- **Lightweight**: Optimized for ESP32 and small microcontrollers.

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
