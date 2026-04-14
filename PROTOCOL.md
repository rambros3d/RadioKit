# RadioKit BLE Protocol — v0x02

## Overview

RadioKit uses a compact binary protocol over BLE or USB Serial.
All multi-byte integers are **little-endian**.

---

## Packet Structure

```
[START][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
  0x55    total      total
```

| Field | Size | Description |
|---|---|---|
| `START` | 1 | Always `0x55` |
| `LENGTH` | 2 | Total packet length including all fields |
| `CMD` | 1 | Command byte |
| `PAYLOAD` | 0–N | Command-specific payload |
| `CRC` | 2 | CRC-16/CCITT-FALSE over `CMD + PAYLOAD` |

Minimum packet size: **6 bytes** (no payload).

---

## Command Bytes

| Value | Name | Direction | Description |
|---|---|---|---|
| `0x10` | `GET_CONF` | App → Arduino | Request configuration descriptor |
| `0x11` | `CONF_DATA` | Arduino → App | Configuration descriptor response |
| `0x20` | `GET_VARS` | App → Arduino | Request current variable state |
| `0x21` | `VAR_DATA` | Arduino → App | Variable state response |
| `0x30` | `SET_INPUT` | App → Arduino | Push input widget values |
| `0x31` | `ACK` | Arduino → App | Acknowledge SET_INPUT |
| `0xF0` | `PING` | App → Arduino | Connectivity check |
| `0xF1` | `PONG` | Arduino → App | Ping response |

---

## CONF_DATA Payload

Sent in response to `GET_CONF`.

### Header (3 bytes)

```
[PROTO_VERSION][ORIENTATION][NUM_WIDGETS]
```

| Byte | Description |
|---|---|
| `PROTO_VERSION` | Protocol version. Current: `0x02` |
| `ORIENTATION` | `0x00` = Landscape, `0x01` = Portrait |
| `NUM_WIDGETS` | Number of widget descriptors that follow |

### Widget Descriptor

```
[TYPE][ID][X][Y][SIZE][ASPECT][ROTATION][LABEL_LEN][LABEL...]
```

| Field | Type | Description |
|---|---|---|
| `TYPE` | `uint8_t` | Widget type ID (see table below) |
| `ID` | `uint8_t` | Widget index (0-based, sequential) |
| `X` | `uint8_t` | Center X on virtual canvas (0–200) |
| `Y` | `uint8_t` | Center Y on virtual canvas (0–200) |
| `SIZE` | `uint8_t` | Height in canvas units (0–200) |
| `ASPECT` | `uint8_t` | Width/height ratio ×10. App computes `width = SIZE × (ASPECT ÷ 10.0)` |
| `ROTATION` | `int8_t` | Rotation in 2° steps |
| `LABEL_LEN` | `uint8_t` | Label byte count (0 = no label) |
| `LABEL` | `char[LABEL_LEN]` | UTF-8 label, **not** null-terminated |

#### ASPECT Encoding

| Wire value | Float ratio | Width when SIZE=20 |
|---|---|---|
| `10` | 1.0 | 20 |
| `16` | 1.6 | 32 |
| `25` | 2.5 | 50 |
| `40` | 4.0 | 80 |
| `50` | 5.0 | 100 |
| `255` | 25.5 | 510 |

#### Widget Type IDs

| `TYPE` | Widget | Input bytes | Output bytes |
|---|---|---|---|
| `0x01` | Button | 1 (`uint8_t` 1=pressed, 0=released) | 0 |
| `0x02` | Switch | 1 (`uint8_t` 1=on, 0=off) | 0 |
| `0x03` | Slider | 1 (`uint8_t` 0–100) | 0 |
| `0x04` | Joystick | 2 (`int8_t` X, `int8_t` Y; −100..+100) | 0 |
| `0x05` | LED | 0 | 1 (`uint8_t` 0=OFF 1=RED 2=GREEN 3=BLUE 4=YELLOW) |
| `0x06` | Text | 0 | 32 (`char[32]`, null-padded) |

---

## VAR_DATA Payload

Contains current runtime state of all widgets:

```
[input widget vars, in widget-ID order]
[output widget vars, in widget-ID order]
```

Input widget bytes are echoed as `0x00` (app owns input state).
Output widget bytes carry the current Arduino-side value.

---

## SET_INPUT Payload

Input widget bytes only, in widget-ID order:

```
[input var 0][input var 1]...
```

Output-only widgets are skipped.

---

## Default Aspect Ratios

| Widget | Wire value | Float |
|---|---|---|
| Button | 25 | 2.5 |
| Switch | 16 | 1.6 |
| Slider | 50 | 5.0 |
| Joystick | 10 | 1.0 |
| LED | 10 | 1.0 |
| Text | 40 | 4.0 |

---

## Transports

### BLE

- Service UUID: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic UUID: `0000FFE1-0000-1000-8000-00805F9B34FB`
- Properties: READ + WRITE + NOTIFY
- Packets fragmented into 20-byte MTU chunks
- Connected state driven by NimBLE connect/disconnect events

### USB Serial

- Same packet format, no fragmentation needed
- Default baud rate: **115200**
- Any Arduino `Stream` is supported (Serial, Serial1, SoftwareSerial, …)
- **Connection timeout:** `isConnected()` returns `true` for **3000 ms** after
  the last valid packet. The app must send `PING` at least every **2000 ms**
  to keep the session alive.
- On first power-up, `isConnected()` returns `false` until the first valid
  packet is received (no false-positive at boot).

#### Recommended app PING interval: 1000 ms
