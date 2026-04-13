# RadioKit

**Control your Arduino from a smartphone — no server, no code generation, just BLE.**

RadioKit is an open-source alternative to RemoteXY. It consists of:

1. **Arduino Library** — Define your UI in code, the library handles BLE communication
2. **Flutter App** (`/app`) — Connects to your Arduino, renders the UI, and sends controls back

No internet required. No account. No web editor. Your Arduino defines the interface in code, and the app renders it automatically.

---

## Quick Start

### Arduino Side

Install the library (copy `src/`, `examples/`, `library.properties`, `keywords.txt` into your Arduino libraries folder, or use the Library Manager when available).

```cpp
#include <RadioKit.h>

RadioKit_Switch  sw;
RadioKit_Slider  slider;
RadioKit_LED     led;
RadioKit_Text    text;

void setup() {
  RadioKit.addWidget(sw,     "Motor",  100, 50,  300, 100);
  RadioKit.addWidget(slider, "Speed",  100, 250, 800, 80);
  RadioKit.addWidget(led,    "Status", 600, 50,  100, 100);
  RadioKit.addWidget(text,   "Info",   100, 450, 800, 100);

  RadioKit.begin("MyRobot");
}

void loop() {
  RadioKit.handle();

  if (sw.isOn()) {
    analogWrite(25, map(slider.value(), 0, 100, 0, 255));
    led.set(RadioKit_LED::GREEN);
    text.set("Running");
  } else {
    analogWrite(25, 0);
    led.set(RadioKit_LED::RED);
    text.set("Stopped");
  }
}
```

### App Side

Open the `/app` folder in your IDE and build with Flutter:

```bash
cd app
flutter pub get
flutter run
```

The app scans for nearby RadioKit BLE devices, connects, downloads the UI layout from the Arduino, and renders it on screen.

#### Web (no install required)

Run the app in your browser to test without installing anything:

```bash
cd app
flutter pub get
flutter run -d chrome
```

Or build and serve a static bundle:

```bash
flutter build web
cd build/web && python3 -m http.server 8080
# open http://localhost:8080
```

> Web Bluetooth requires **Chrome or Edge** (desktop or Android). Firefox and Safari do not support the Web Bluetooth API. The page must be served over **https** or **localhost**.

---

## Supported Widgets

| Widget   | Type     | Data      | Description                              |
|----------|----------|-----------|------------------------------------------|
| Button   | Input    | 1 byte    | Momentary press (1 while held, 0 released) |
| Switch   | Input    | 1 byte    | Toggle ON/OFF (1 or 0)                   |
| Slider   | Input    | 1 byte    | Linear value 0–100                       |
| Joystick | Input    | 2 bytes   | X,Y each -100 to +100                    |
| LED      | Output   | 1 byte    | Color indicator (off, red, green, blue, yellow) |
| Text     | Output   | 32 bytes  | Read-only text display                   |

---

## Supported Hardware

- **ESP32** boards (any variant with built-in BLE)
- Communication: **Bluetooth Low Energy (BLE)**

The app runs on **Android**, **iOS**, and **Web** (Chrome/Edge — no install required).

---

## Repository Layout

```
/
├── src/               # Arduino library source files
├── examples/          # Arduino example sketches
│   ├── BasicSwitch/   # Toggle switch → LED
│   ├── SliderServo/   # Slider → servo control
│   └── JoystickMotor/ # Joystick → dual motor + LED
├── app/               # Flutter companion app
│   ├── lib/           # Dart source (models, services, providers, screens, widgets)
│   ├── android/       # Android platform config (BLE permissions)
│   ├── ios/           # iOS platform config (Info.plist, Podfile)
│   └── test/          # Unit tests (CRC, protocol parsing)
├── PROTOCOL.md        # Binary protocol specification
├── library.properties # Arduino Library Manager metadata
├── keywords.txt       # Arduino IDE syntax highlighting
└── LICENSE            # MIT
```

---

## Protocol

RadioKit uses a custom binary protocol over BLE UART (service UUID `0000FFE0-...`). See [PROTOCOL.md](PROTOCOL.md) for the full specification.

**Connection flow:**
1. App discovers and connects to the BLE device
2. App sends `GET_CONF` → Arduino responds with `CONF_DATA` (all widget definitions)
3. App renders the UI, then enters a polling loop:
   - `GET_VARS` every 100ms to sync output values (LEDs, text)
   - `SET_INPUT` when the user interacts with a control widget
   - `PING`/`PONG` every 2s for connection health

---

## Wiring (ESP32)

No external modules needed — ESP32 has BLE built in.

1. Upload your sketch to the ESP32
2. Open the RadioKit app on your phone
3. Tap your device in the scan list
4. Control it

---

## Examples

### BasicSwitch
Toggle switch controls the built-in LED. LED widget shows ON/OFF status. Text widget displays the current state.

### SliderServo
Slider controls a servo motor (0–180°). Text widget shows the current angle.

### JoystickMotor
Joystick X/Y control two motors via PWM. LED widget indicates movement direction. Button is emergency stop.

---

## License

MIT — see [LICENSE](LICENSE).
