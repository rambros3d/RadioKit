# RadioKit Arduino Library

> Control your Arduino projects from a mobile app over BLE or Serial. No cloud, no code generation—just pure performance.

---

## What is RadioKit?

RadioKit is a powerful, object-oriented Arduino library that bridges your hardware and a highly customizable mobile dashboard. It allows you to build industrial-grade control interfaces using simple C++ structures.

### Key Features

- **Hardware Agnostic**: Supports ESP32 (NimBLE), Nordic nRF52, STM32, and any board with a Hardware Serial port.
- **Tailored Memory Model**: Each widget only consumes the RAM it needs.
- **Zero Configuration**: The UI is defined in your Arduino code; the app dynamically builds the dashboard upon connection.
- **Reliable Communication**: Built-in sequence tracking and retransmission for critical commands.

## Sections

- **[Getting Started](setup.md)**: Install the library and create your first sketch.
- **[Widgets Reference](widgets.md)**: Explore the available input and output controls.
- **[UI & Layout](ui_layout.md)**: Learn how to position and scale your widgets.
- **[Protocol Specification](protocol.md)**: Details on the binary packet format (for advanced users).

## Installation

1. Download the latest release from [GitHub](https://github.com/rambros3d/RadioKit/releases).
2. Extract the ZIP into your `Documents/Arduino/libraries` folder.
3. Restart your Arduino IDE.
4. Try the example in `File -> Examples -> RadioKit -> SimpleDemo`.
