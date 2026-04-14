# RadioKit Arduino Library — Implementation Plan

**Version:** 2.0.0-plan  
**Date:** 2026-04-14  
**Scope:** Arduino library only (`src/`) — Flutter app changes deferred

---

## Overview

This document consolidates all planned changes to the RadioKit Arduino library:

1. **Struct sync architecture** — replace OOP widget objects with a flat struct + config macro system (inspired by RemoteXY)
2. **Orientation-aware virtual canvas** — `200×100` landscape / `100×200` portrait
3. **Bottom-left origin `(0, 0)`** with center-based widget positioning
4. **Per-widget rotation** encoded as a mapped `int8_t`

These changes are **breaking** at both the sketch API level and the wire protocol level. `RK_PROTOCOL_VERSION` must be bumped from `0x01` → `0x02`.

---

## 1. Architecture Change — Struct Sync

### Current Approach (OOP Widget Objects)

The current library uses discrete C++ widget objects. Each widget is instantiated, registered with `addWidget()`, and read/written via methods:

```cpp
RadioKit_Button btn;
RadioKit_LED    led;

RadioKit.addWidget(btn, "Fire", 20, 50, 25, 20);
RadioKit.addWidget(led, "Status", 150, 50, 15, 15);
RadioKit.begin("MyBot");

// In loop:
if (btn.pressed()) led.set(RadioKit_LED::GREEN);
```

### New Approach (Struct Sync)

Inspired by RemoteXY's design. The user defines:
1. A **config block** using macros — declares widget layout at compile time
2. A **flat struct** — one field per widget value; all I/O lives here
3. Calls `RadioKit.begin("Name", &myStruct)` — ties config + struct together

```cpp
#include <RadioKit.h>

// 1. Config block — widget layout
RK_CONFIG_BEGIN(RK_LANDSCAPE)
    RK_BUTTON  (20,  50, 25, 20, 0,  "Fire")
    RK_SWITCH  (60,  50, 25, 15, 0,  "Light")
    RK_SLIDER  (100, 50, 60, 12, 0,  "Speed")
    RK_JOYSTICK(160, 50, 35, 35, 0,  "Drive")
    RK_LED     (20,  20, 12, 12, 0,  "Status")
    RK_TEXT    (100, 80, 70, 15, 0,  "Sensor")
RK_CONFIG_END

// 2. Flat struct — fields in same order as config macros
struct {
    // inputs (App → Arduino) — one field per input widget, in registration order
    uint8_t fire;           // Button:   1 = pressed, 0 = released
    uint8_t light;          // Switch:   1 = on, 0 = off
    uint8_t speed;          // Slider:   0–100
    int8_t  driveX;         // Joystick: X axis -100..+100
    int8_t  driveY;         // Joystick: Y axis -100..+100
    // outputs (Arduino → App) — one field per output widget, in registration order
    uint8_t statusLed;      // LED:  0=off 1=red 2=green 3=blue 4=yellow
    char    sensorText[32]; // Text: null-terminated string
    // meta
    uint8_t connect_flag;   // set to 1 by library when app is connected
} rk;

void setup() {
    RadioKit.begin("MyBot", &rk);
}

void loop() {
    RadioKit.handle();

    if (rk.fire)  rk.statusLed = RK_LED_GREEN;
    analogWrite(PWM_PIN, map(rk.speed, 0, 100, 0, 255));
    snprintf(rk.sensorText, 32, "A0=%d", analogRead(A0));
}
```

### How the Library Uses the Struct

The config macros build a `PROGMEM` byte array at compile time. This array encodes:
- Canvas orientation
- Widget count
- Per-widget: type, position, size, rotation, label
- Per-widget: **byte offset** into the user struct for its value field(s)

At runtime, `RadioKit.handle()` serializes/deserializes the struct directly by casting `&rk` to `uint8_t*` and using the pre-computed offsets from the config array. No virtual dispatch, no OOP overhead.

---

## 2. Coordinate System Specification

### Canvas Dimensions

| Orientation | Wire Byte | Canvas Width | Canvas Height |
|---|---|---|---|
| Landscape | `0x00` | 200 | 100 |
| Portrait  | `0x01` | 100 | 200 |

All coordinate values fit in `uint8_t` (max 200).

### Axis Convention

```
(0, canvasH)  ┌──────────────────────┐  (canvasW, canvasH)
              │                      │
              │    Y increases ↑     │
              │                      │
              │    X increases →     │
              │                      │
       (0, 0) └──────────────────────┘  (canvasW, 0)
              bottom-left is origin
```

- **`(0, 0)`** = bottom-left corner of the screen
- **X** increases rightward
- **Y** increases upward (standard Cartesian — opposite of screen convention)

### Widget Position & Size

- `X`, `Y` = **center point** of the widget (not top-left corner)
- `W`, `H` = total width and height
- A widget at `(X, Y)` with size `(W, H)` occupies:
  - Horizontally: `X − W/2` to `X + W/2`
  - Vertically:   `Y − H/2` to `Y + H/2`

### Widget Rotation

- User-facing macro accepts degrees: **`-180` to `+180`**
- Stored on wire as **`int8_t`** mapped to **`-90` to `+90`** (2° resolution)

```
stored      = round(userDeg / 2)   // compile-time, in config macro
displayDeg  = stored × 2          // Flutter-side, at render time
```

- Default: `0` (no rotation)
- Positive = counter-clockwise

---

## 3. Config Macro System — New File `src/RadioKitConfig.h`

This new header defines the compile-time config DSL.

### Macro Definitions

```cpp
// Begin config block — declares PROGMEM byte array and sets orientation
#define RK_CONFIG_BEGIN(orientation) \
    static const uint8_t PROGMEM _rk_config[] = { \
        RK_PROTOCOL_VERSION, (uint8_t)(orientation),

// One entry per widget type — args: x, y, w, h, rotation(-180..180), label
#define RK_BUTTON(x, y, w, h, rot, label)    /* encodes type+layout+offset */
#define RK_SWITCH(x, y, w, h, rot, label)
#define RK_SLIDER(x, y, w, h, rot, label)
#define RK_JOYSTICK(x, y, w, h, rot, label)  /* 2 bytes: X then Y */
#define RK_LED(x, y, w, h, rot, label)
#define RK_TEXT(x, y, w, h, rot, label)      /* 32 bytes */

// End config block — writes widget count and closes array
#define RK_CONFIG_END    };
```

### LED Color Constants (replaces enum methods)

```cpp
#define RK_LED_OFF    0
#define RK_LED_RED    1
#define RK_LED_GREEN  2
#define RK_LED_BLUE   3
#define RK_LED_YELLOW 4
```

### Struct Field Size Reference

| Widget | Input fields | Input bytes | Output fields | Output bytes |
|---|---|---|---|---|
| `RK_BUTTON` | `uint8_t` | 1 | — | 0 |
| `RK_SWITCH` | `uint8_t` | 1 | — | 0 |
| `RK_SLIDER` | `uint8_t` | 1 | — | 0 |
| `RK_JOYSTICK` | `int8_t, int8_t` | 2 | — | 0 |
| `RK_LED` | — | 0 | `uint8_t` | 1 |
| `RK_TEXT` | — | 0 | `char[32]` | 32 |

> **Field ordering rule:** All input widget fields must appear first in the struct (in config registration order), followed by all output widget fields, then the optional `connect_flag` last. This mirrors the `VAR_DATA` wire layout.

---

## 4. Files to Change

### 4.1 `src/RadioKitConfig.h` — **NEW FILE**

- Config DSL macros (`RK_CONFIG_BEGIN`, `RK_BUTTON`, `RK_SWITCH`, etc.)
- LED color `#define` constants (`RK_LED_OFF`, `RK_LED_GREEN`, etc.)
- Orientation enum and canvas dimension constants
- Struct field size documentation comments

---

### 4.2 `src/widgets/Widget.h` — **RETIRED**

The OOP widget base class and all subclasses (`Button.h/.cpp`, `Switch.h/.cpp`, etc.) are **removed**. Their type ID constants move to `RadioKitConfig.h`:

```cpp
#define RK_TYPE_BUTTON   0x01
#define RK_TYPE_SWITCH   0x02
#define RK_TYPE_SLIDER   0x03
#define RK_TYPE_JOYSTICK 0x04
#define RK_TYPE_LED      0x05
#define RK_TYPE_TEXT     0x06
```

---

### 4.3 `src/RadioKitWidgets.h` — **RETIRED**

This aggregator header is removed alongside the widget class files.

---

### 4.4 `src/RadioKitProtocol.h`

**Changes:**
- Bump `RK_PROTOCOL_VERSION` from `0x01` → `0x02`
- Update `RK_MAX_PACKET_SIZE` comment — new descriptor size is `8 + labelLen` bytes (was `11 + labelLen`)
- No changes to packet framing, CRC, or command IDs

```cpp
#define RK_PROTOCOL_VERSION  0x02

// 16 widgets × (1+1+1+1+1+1+1+1+32) = 16 × 40 = 640 bytes + overhead
#define RK_MAX_PACKET_SIZE  768   // value unchanged, still sufficient
```

---

### 4.5 `src/RadioKit.h`

**Changes:**
- Remove all `addWidget()` overloads and widget registry
- Remove `widgetCount()` (or keep as debug helper reading from config)
- Update `begin()` signature to accept struct pointer:
  ```cpp
  void begin(const char* deviceName, void* structPtr);
  ```
- Add private members:
  ```cpp
  void*    _structPtr;       // pointer to user's flat struct
  uint16_t _inputBytes;      // total input bytes computed from config
  uint16_t _outputBytes;     // total output bytes computed from config
  uint8_t  _connectFlagOffset; // byte offset of connect_flag in struct
  ```
- Remove `_orientation` member (now embedded in `_rk_config[]` PROGMEM array)

---

### 4.6 `src/RadioKit.cpp`

**Changes:**

#### `begin(deviceName, structPtr)`
- Store `_structPtr`
- Walk `_rk_config[]` PROGMEM array to compute `_inputBytes`, `_outputBytes`, widget count
- Start BLE advertising

#### `_buildConfPayload()`
- Reads directly from `_rk_config[]` PROGMEM — the config array **is** the CONF_DATA payload
- No per-widget loop needed; just copy from PROGMEM into the TX buffer

#### `_buildVarPayload()`
- Copies `_inputBytes + _outputBytes` bytes directly from `(uint8_t*)_structPtr` into TX buffer
- Input bytes at offset 0, output bytes immediately after (struct field ordering enforces this)

#### `_handleSetInput(payload, len)`
- Copies `_inputBytes` bytes from `payload` directly into `(uint8_t*)_structPtr`
- No per-widget deserialize loop

#### `handle()`
- Set `connect_flag` in struct via `_connectFlagOffset` on connect/disconnect

---

### 4.7 `src/RadioKitProtocol.cpp`

No functional changes — CRC, packet builder, and RX state machine are unaffected.

---

### 4.8 `src/connection/RadioKitBLE.h/.cpp`

No changes — BLE transport layer is unaffected.

---

### 4.9 `PROTOCOL.md`

**Changes:**
- Replace `1000×1000` with orientation-aware coordinate spec
- Add orientation byte to `CONF_DATA` header
- Update widget descriptor table (X/Y/W/H = 1 byte each, add ROTATION field)
- Add coordinate system section (bottom-left origin, center positioning, Y-axis direction)
- Add rotation encoding table
- Bump protocol version reference to `0x02`

#### Updated `CONF_DATA` Payload Format

```
[PROTOCOL_VERSION][ORIENTATION][NUM_WIDGETS][WIDGET_1]...[WIDGET_N]
```

| Field | Size | Description |
|---|---|---|
| PROTOCOL_VERSION | 1 byte | `0x02` |
| ORIENTATION | 1 byte | `0x00` = Landscape (200×100), `0x01` = Portrait (100×200) |
| NUM_WIDGETS | 1 byte | Number of widget descriptors |

#### Updated Widget Descriptor

```
[TYPE_ID][WIDGET_ID][X][Y][W][H][ROTATION][LABEL_LEN][LABEL...]
```

| Field | Size | Description |
|---|---|---|
| TYPE_ID | 1 byte | Widget type (0x01–0x06) |
| WIDGET_ID | 1 byte | Sequential ID (0-based) |
| X | 1 byte | Center X — `uint8_t` |
| Y | 1 byte | Center Y — `uint8_t` |
| W | 1 byte | Width — `uint8_t` |
| H | 1 byte | Height — `uint8_t` |
| ROTATION | 1 byte | `int8_t` mapped, `−90` to `+90` (×2 = actual degrees) |
| LABEL_LEN | 1 byte | Label byte count |
| LABEL | N bytes | UTF-8 label, no null terminator |

---

### 4.10 `docs/functions.md`

- Full rewrite to reflect struct-based sketch API (see companion file)

---

## 5. Protocol Wire Impact

| Metric | v1 (current) | v2 (planned) |
|---|---|---|
| Protocol version | `0x01` | `0x02` |
| CONF_DATA header | 2 bytes | 3 bytes (+orientation) |
| Widget descriptor | `11 + labelLen` bytes | `8 + labelLen` bytes |
| X/Y/W/H encoding | `uint16_t` LE (2 bytes each) | `uint8_t` (1 byte each) |
| Rotation field | absent | `int8_t`, 1 byte |
| Net per widget | — | −3 bytes |
| Net for 16 widgets | — | −47 bytes |
| VAR_DATA format | per-widget serialize loop | flat struct memcpy |
| SET_INPUT format | per-widget deserialize loop | flat struct memcpy |

---

## 6. Backward Compatibility

### Protocol — BREAKING
A v1 app will misparse v2 `CONF_DATA` because:
- Header gains an orientation byte, shifting all widget offsets by 1
- X/Y/W/H fields halved from 2 bytes to 1 byte each
- New ROTATION field present

The `RK_PROTOCOL_VERSION = 0x02` byte allows future apps to detect and reject incompatible firmware with a clear error message.

### Sketch API — BREAKING
The OOP widget object pattern is fully replaced. Existing sketches must be rewritten to use the struct+config macro pattern. The migration is straightforward:

| Old | New |
|---|---|
| `RadioKit_Button btn;` | `uint8_t btn;` in struct |
| `RadioKit.addWidget(btn, ...)` | `RK_BUTTON(...)` in config block |
| `btn.pressed()` | `if (rk.btn)` (rising edge handling moved to app or helper) |
| `led.set(RadioKit_LED::GREEN)` | `rk.led = RK_LED_GREEN;` |
| `RadioKit.begin("Name")` | `RadioKit.begin("Name", &rk)` |

> **Note:** The `pressed()` rising-edge detection (one-shot on leading edge) is lost in the plain struct approach. If needed, a `RK_RISING(field, prev)` macro helper can be provided.

---

## 7. Implementation Order

Execute in this order to minimise broken intermediate states:

1. **`src/RadioKitProtocol.h`** — bump `RK_PROTOCOL_VERSION` to `0x02`, update comments
2. **`src/RadioKitConfig.h`** — create new file with macros, constants, enums
3. **`src/RadioKit.h`** — update `begin()` signature, remove widget registry, add struct members
4. **`src/RadioKit.cpp`** — implement new `begin()`, `_buildConfPayload()`, `_buildVarPayload()`, `_handleSetInput()`
5. **`src/RadioKitProtocol.cpp`** — no changes needed
6. **`src/connection/RadioKitBLE.h/.cpp`** — no changes needed
7. **`src/widgets/`** — delete all widget class files
8. **`src/RadioKitWidgets.h`** — delete
9. **`PROTOCOL.md`** — update wire format documentation
10. **`examples/`** — rewrite example sketches for new struct API
11. **`docs/functions.md`** — update function reference

---

## 8. Flutter App Notes (Deferred)

The following Flutter-side changes are out of scope for this phase:

- Parse `PROTOCOL_VERSION = 0x02` and reject `0x01` firmware with a UI error
- Parse orientation byte from `CONF_DATA` header
- Flip Y axis at render time: `screenY = canvasH − virtualY`
- Offset widget from center: `topLeft = (screenX − w/2, screenY − h/2)`
- Scale: `scaleX = screenW / canvasW`, `scaleY = screenH / canvasH`
- Apply `rotation × 2` degrees when rendering each widget
- Receive flat `VAR_DATA` payload and unpack by offset (not by widget object)
- Send flat `SET_INPUT` payload packed by offset
