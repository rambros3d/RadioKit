# RadioKit Binary Protocol Specification v2.0

## Overview

RadioKit uses a simple binary protocol over BLE (UART service) to exchange UI configuration and variable data between an Arduino device and a Flutter app.

**BLE Service UUID:** `0000FFE0-0000-1000-8000-00805F9B34FB`  
**BLE Characteristic UUID:** `0000FFE1-0000-1000-8000-00805F9B34FB`

---

## Packet Format

All packets share this structure:

```
[START] [LENGTH_LO] [LENGTH_HI] [CMD] [PAYLOAD...] [CRC_LO] [CRC_HI]
```

| Field | Size | Description |
|---|---|---|
| START | 1 byte | Always `0x55` |
| LENGTH | 2 bytes | Total packet length (little-endian), including header + CRC |
| CMD | 1 byte | Command identifier |
| PAYLOAD | N bytes | Command-specific data |
| CRC | 2 bytes | CRC-16/CCITT over CMD + PAYLOAD (little-endian) |

**Minimum packet size:** 6 bytes (start + length + cmd + crc, no payload)

---

## CRC-16 Calculation

CRC-16/CCITT (poly `0x1021`, init `0xFFFF`) computed over CMD + PAYLOAD bytes.

---

## Commands

| CMD | Name | Direction | Description |
|---|---|---|---|
| `0x01` | GET_CONF | App → Arduino | Request UI configuration |
| `0x02` | CONF_DATA | Arduino → App | UI configuration response |
| `0x03` | GET_VARS | App → Arduino | Request current variable values |
| `0x04` | VAR_DATA | Arduino → App | Current variable values |
| `0x05` | SET_INPUT | App → Arduino | Set input variable values |
| `0x06` | ACK | Arduino → App | Acknowledgment |
| `0x07` | PING | App → Arduino | Keep-alive ping |
| `0x08` | PONG | Arduino → App | Keep-alive pong |

---

## Coordinate System

### Virtual Canvas

All widget positions are expressed in a virtual coordinate system whose size depends on orientation:

| Orientation | Wire Byte | Canvas Width | Canvas Height |
|---|---|---|---|
| Landscape | `0x00` | 200 | 100 |
| Portrait | `0x01` | 100 | 200 |

All coordinate and size values are `uint8_t` (0–255, max canvas dimension is 200).

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

- **`(0, 0)`** = bottom-left corner (standard Cartesian convention)
- **X** increases rightward
- **Y** increases upward (opposite of typical screen coordinates)

### Widget Position

`X` and `Y` in the descriptor refer to the **center point** of the widget:

- A widget at `(X, Y)` with size `(W, H)` occupies:
  - Horizontally: `X − W/2` to `X + W/2`
  - Vertically: `Y − H/2` to `Y + H/2`

### Flutter Render Transform

To convert virtual coords to screen pixel coords:

```
scaleX  = screenWidth  / canvasWidth
scaleY  = screenHeight / canvasHeight
screenX = X * scaleX
screenY = (canvasHeight - Y) * scaleY   ← Y-axis flip
topLeft = (screenX - W/2 * scaleX, screenY - H/2 * scaleY)
```

---

## Widget Types

| Type ID | Name | Input bytes | Output bytes | Description |
|---|---|---|---|---|
| `0x01` | BUTTON | 1 | 0 | Momentary push: `1`=pressed, `0`=released |
| `0x02` | SWITCH | 1 | 0 | Toggle: `1`=ON, `0`=OFF |
| `0x03` | SLIDER | 1 | 0 | Linear `0`–`100` |
| `0x04` | JOYSTICK | 2 | 0 | X then Y, each `int8_t` (`-100` to `+100`) |
| `0x05` | LED | 0 | 1 | Color: `0`=off `1`=red `2`=green `3`=blue `4`=yellow |
| `0x06` | TEXT | 0 | 32 | Null-terminated UTF-8 string display |

---

## CONF_DATA Payload Format

```
[PROTOCOL_VERSION] [ORIENTATION] [NUM_WIDGETS] [WIDGET_1] ... [WIDGET_N]
```

| Field | Size | Description |
|---|---|---|
| PROTOCOL_VERSION | 1 byte | `0x02` |
| ORIENTATION | 1 byte | `0x00` = Landscape (200×100), `0x01` = Portrait (100×200) |
| NUM_WIDGETS | 1 byte | Number of widget descriptors that follow |

### Widget Descriptor

```
[TYPE_ID] [WIDGET_ID] [X] [Y] [W] [H] [ROTATION] [LABEL_LEN] [LABEL...]
```

| Field | Size | Description |
|---|---|---|
| TYPE_ID | 1 byte | Widget type (see table above) |
| WIDGET_ID | 1 byte | Sequential zero-based index (0–255) |
| X | 1 byte | Center X — `uint8_t` (0 = left edge) |
| Y | 1 byte | Center Y — `uint8_t` (0 = bottom edge) |
| W | 1 byte | Width — `uint8_t` |
| H | 1 byte | Height — `uint8_t` |
| ROTATION | 1 byte | `int8_t` mapped: `−90` to `+90` (multiply × 2 to get actual degrees) |
| LABEL_LEN | 1 byte | Byte length of following label |
| LABEL | N bytes | UTF-8 label string, **no null terminator** |

### Rotation Encoding

| User degrees | Wire `int8_t` | Notes |
|---|---|---|
| `0°` | `0` | No rotation (default) |
| `90°` | `45` | Quarter turn CCW |
| `-90°` | `-45` | Quarter turn CW |
| `180°` | `90` | Half turn |
| `-180°` | `-90` | Half turn (opposite sign) |

Positive = counter-clockwise (standard mathematical convention).

---

## VAR_DATA Payload Format

All input and output variable bytes from the user's flat struct, packed sequentially:

```
[INPUT_VARS...] [OUTPUT_VARS...]
```

- **Input bytes first** — all widgets with input data, in widget registration order
- **Output bytes after** — all widgets with output data, in widget registration order
- Sizes per widget type as defined in the widget table above
- The app must use the CONF_DATA descriptor to compute byte offsets

---

## SET_INPUT Payload Format

Same layout as the **input portion** of VAR_DATA. The app sends all input variable values packed in widget order.

On receipt the Arduino library does a direct `memcpy` into the user struct at offset 0.

---

## connect_flag

The optional `uint8_t connect_flag` field at the **end** of the user struct (after all input and output fields) is set to `1` by the library when a BLE connection is active, and `0` on disconnect. It is **never transmitted over the wire** — it is a local status field only.

---

## Connection Flow

1. App scans for BLE devices advertising the RadioKit service UUID
2. App connects and discovers the UART characteristic
3. App sends `GET_CONF`
4. Arduino responds with `CONF_DATA` (protocol version `0x02`)
5. App validates `PROTOCOL_VERSION` — rejects `0x01` firmware with an error message
6. App renders the UI from the descriptor
7. App enters polling loop:
   - Sends `GET_VARS` every ~100 ms → receives `VAR_DATA`
   - On user interaction: sends `SET_INPUT` → Arduino responds `ACK`
8. Periodic `PING` / `PONG` every 2 s for connection health
