# RadioKit Protocol - v3.0

## Overview

RadioKit uses a compact binary protocol which is transport-agnostic (works for BLE and Serial). The protocol is designed for low-latency, reliable control with minimal overhead.

---

## Packet Structure

```
[START][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
  0x55    total      total
```

| Field     | Size | Description                              |
|-----------|------|------------------------------------------|
| `START`   | 1    | Always `0x55`                            |
| `LENGTH`  | 2    | Total packet length including all fields |
| `CMD`     | 1    | Command byte                             |
| `PAYLOAD` | 0–N  | Command-specific payload                 |
| `CRC`     | 2    | CRC-16/CCITT-FALSE over `CMD + PAYLOAD`  |

Minimum packet size: **6 bytes** (no payload).

---

## Command Bytes

| Value  | Name         | Direction     | Description                           |
|--------|--------------|---------------|---------------------------------------|
| `0x01` | `GET_CONF`   | App → Arduino | Request configuration descriptor      |
| `0x02` | `CONF_DATA`  | Arduino → App | Configuration descriptor response     |
| `0x03` | `GET_VARS`   | App → Arduino | Request current variable state        |
| `0x04` | `VAR_DATA`   | Arduino → App | Variable state response               |
| `0x05` | `GET_META`   | App → Arduino | Request widget metadata               |
| `0x06` | `META_DATA`  | Arduino → App | Metadata response                     |
| `0x07` | `SET_INPUT`  | App → Arduino | Set input widget state                |
| `0x08` | `ACK`        | Both          | Acknowledge reliable packet           |
| `0x09` | `PING`       | App → Arduino | Connectivity check                    |
| `0x0A` | `PONG`       | Arduino → App | Ping response                         |
| `0x0B` | `VAR_UPDATE` | Both          | Reliable push of a single widget state|
| `0x0C` | `META_UPDATE`| Both          | Reliable push of widget metadata      |
| `0x0D` | `TELEMETRY`  | Arduino → App | Telemetry data (RSSI, uptime, etc.)   |

---

## CONF_DATA (Configuration)

Sent in response to `GET_CONF`. Contains device configuration and widget descriptors.

### Global Header

```
[PROTO_VER][ORIENT][WIDGET_COUNT][NAME_LEN][NAME...][DESC_LEN][DESC...]
[THEME_LEN][THEME...][VERSION_LEN][VERSION...]
```

| Field           | Type      | Description                                            |
|-----------------|-----------|--------------------------------------------------------|
| `PROTO_VER`     | `uint8_t` | Protocol version (current: `0x03`)                     |
| `ORIENT`        | `uint8_t` | `0x00` = Landscape, `0x01` = Portrait                  |
| `WIDGET_COUNT`  | `uint8_t` | Number of widget descriptors that follow               |
| `NAME_LEN`      | `uint8_t` | Length of device name string                           |
| `NAME`          | `char[N]` | Device identity name (UTF-8)                           |
| `DESC_LEN`      | `uint8_t` | Length of description string                           |
| `DESC`          | `char[N]` | Device description (UTF-8)                             |
| `THEME_LEN`     | `uint8_t` | Length of theme identifier string                      |
| `THEME`         | `char[N]` | Theme name (e.g., `"default"`, `"dark"`, `"retro"`)    |
| `VERSION_LEN`   | `uint8_t` | Length of version string                               |
| `VERSION`       | `char[N]` | Firmware version (UTF-8)                               |

### Widget Descriptor

Each widget is described by a fixed header followed by optional string data.

```
[TYPE][ID][X][Y][SCALE][ASPECT][ROT_LO][ROT_HI][STYLE][VARIANT][STR_MASK][STR_DATA...]
```

| Field      | Type      | Description                                               |
|------------|-----------|-----------------------------------------------------------|
| `TYPE`     | `uint8_t` | Widget type ID (see table below)                          |
| `ID`       | `uint8_t` | Widget index (0-based, sequential)                        |
| `X`        | `uint8_t` | Center X on virtual canvas (0–200)                        |
| `Y`        | `uint8_t` | Center Y on virtual canvas (0–200)                        |
| `SCALE`    | `uint8_t` | Scale ×10 (e.g., `10` = 1.0×, `20` = 2.0×)                |
| `ASPECT`   | `uint8_t` | Aspect ratio ×10 (e.g., `50` = 5.0, for Slider/Text)      |
| `ROTATION` | `int16_t` | Rotation in degrees (clockwise)                           |
| `STYLE`    | `uint8_t` | Visual style (0=primary, 1=dim, 2=success, 3=warning, 4=danger) |
| `VARIANT`  | `uint8_t` | Behavioral variation (centering mode + detent count)      |
| `STR_MASK` | `uint8_t` | String bitmask (determines following string segments)     |

#### Widget Type IDs

| ID  | Widget          | Description                          |
|-----|-----------------|--------------------------------------|
| 1   | PushButton      | Momentary button                     |
| 2   | ToggleButton    | Latching button                      |
| 3   | SlideSwitch     | iOS-style toggle switch              |
| 4   | Slider          | Linear slider (-100 to +100)         |
| 5   | Knob            | Rotary knob (-100 to +100)           |
| 6   | Joystick        | 2-axis joystick                      |
| 7   | LED             | Status indicator                     |
| 8   | Text            | Read-only text display               |
| 9   | MultipleButton  | Radio-style button group             |
| 10  | MultipleSelect  | Checkbox-style group                 |

#### String Bitmask (`STR_MASK`)

Bits indicate which optional strings are included. Each active bit adds a `[LEN][STR]` pair to the `STR_DATA` block.

- **Bit 0 (0x01)**: Label (primary display text)
- **Bit 1 (0x02)**: Icon (standard name string)
- **Bit 2 (0x04)**: OnText (for buttons)
- **Bit 3 (0x08)**: OffText (for buttons)
- **Bit 4 (0x10)**: Content (for Text widget initial value)

Each string is encoded as: `[LENGTH (1 byte)][UTF-8 DATA]`

---

## Runtime Communication

### VAR_DATA (Full State Sync)

Sent in response to `GET_VARS`. Contains the current state of all widgets in ID order.

```
[DATA_W0][DATA_W1][DATA_W2]...
```

Each widget's data is encoded according to its type:

| Type  | Widget          | Data Bytes                              | Description                     |
|-------|-----------------|-----------------------------------------|---------------------------------|
| 1     | PushButton      | 1 byte                                  | Current state (0/1)             |
| 2     | ToggleButton    | 1 byte                                  | Current state (0/1)             |
| 3     | SlideSwitch     | 1 byte                                  | Current state (0/1)             |
| 4     | Slider          | 1 byte                                  | Value (-100 to +100, offset 128)|
| 5     | Knob            | 1 byte                                  | Value (-100 to +100, offset 128)|
| 6     | Joystick        | 2 bytes                                 | X, Y values (each offset 128)   |
| 7     | LED             | 4 bytes                                 | State (1), R, G, B              |
| 8     | Text            | 32 bytes                                | UTF-8 string (null-padded)      |
| 9     | MultipleButton  | 1 byte                                  | Bitmask of selected items       |
| 10    | MultipleSelect  | 1 byte                                  | Bitmask of selected items       |

### SET_INPUT (App → Arduino)

Sent by the app when the user interacts with an input widget.

```
[ID][VALUE...]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `ID`   | `uint8_t` | Widget index                             |
| `VALUE`| variable  | Type-specific value (see VAR_DATA table) |

The Arduino processes the input and may update internal state or trigger actions.

### VAR_UPDATE (Reliable Push)

Pushes a change for a single widget. Can be sent by either side:
- **App → Arduino**: When user changes an input (alternative to SET_INPUT with reliability)
- **Arduino → App**: When firmware programmatically changes a widget state

```
[ID][SEQ][DATA...]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `ID`   | `uint8_t` | Widget index                             |
| `SEQ`  | `uint8_t` | Rolling sequence number (0-255)          |
| `DATA` | variable  | Type-specific value (see VAR_DATA table) |

#### Reliability Logic

- The sender maintains a **pending bitmask** (32-bit) for unacknowledged updates
- Retransmission timeout: **200 ms**
- Maximum retries: **5 attempts**
- After 5 failures, the packet is dropped (fail-soft)
- The receiver sends `ACK` immediately upon receipt

### ACK (Acknowledgment)

Confirms receipt of a reliable packet (`VAR_UPDATE` or `META_UPDATE`).

```
[SEQ]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `SEQ`  | `uint8_t` | Sequence number being acknowledged       |

### META_DATA & META_UPDATE

Same format as VAR_DATA/VAR_UPDATE but for widget metadata (label, icon, etc.). Used when firmware changes widget appearance at runtime.

### TELEMETRY (Arduino → App)

Periodic status updates (optional).

```
[FLAGS][RSSI][UPTIME_LO][UPTIME_HI][UPTIME_MS_LO][UPTIME_MS_HI]
```

| Field   | Type      | Description                              |
|---------|-----------|------------------------------------------|
| `FLAGS` | `uint8_t` | Bit 0: Connected, Bit 1: Has BLE, etc.   |
| `RSSI`  | `int8_t`  | Signal strength (dBm, 127 if N/A)        |
| `UPTIME`| `uint32_t`| Milliseconds since boot                  |

---

## Transports

### BLE (NimBLE)

| Role           | UUID                                     |
|----------------|------------------------------------------|
| **Service**    | `0000FFE0-0000-1000-8000-00805F9B34FB`   |
| **Characteristic** | `0000FFE1-0000-1000-8000-00805F9B34FB`   |

- **Properties**: Write (no response), Notify, Indicate
- **MTU**: 23 bytes (default), negotiated up to 517
- **Packet fragmentation**: Handled by NimBLE for packets > MTU
- **Flow control**: Credit-based (app grants credits for sends)

### USB Serial / UART

- **Baud rate**: 115200 (recommended), any speed supported
- **Connection timeout**: 3000 ms after last valid packet
- **Recommended PING interval**: 1000 ms
- **Hardware flow control**: Optional (RTS/CTS)

### Web Serial (Chrome/Edge)

- Same as USB Serial
- Browser handles serial port selection
- No baud rate restrictions (virtual port)

---

## Timing & Keepalive

- **PING interval**: 1000–2000 ms (app → Arduino)
- **PONG timeout**: 3000 ms (no response = disconnected)
- **VAR_UPDATE retry**: 200 ms interval, 5 max retries
- **Connection timeout**: 5000 ms (no data from either side)

---

## Error Handling

- **CRC mismatch**: Packet silently discarded
- **Invalid START byte**: Stream resynchronized on next `0x55`
- **Unknown CMD**: Packet ignored (future compatibility)
- **Buffer overflow**: Packet truncated, connection reset
- **Reliable packet timeout**: Retransmit up to 5 times, then drop

---

## Example Session

```
App → Arduino:  GET_CONF
Arduino → App: CONF_DATA (with all widget descriptors)
App → Arduino: GET_VARS
Arduino → App: VAR_DATA (current state of all widgets)
[User taps button]
App → Arduino: SET_INPUT (or VAR_UPDATE) with new state
Arduino → App: ACK
[LED state changes programmatically]
Arduino → App: VAR_UPDATE (with LED new state)
App → Arduino: ACK
```

---

## Version History

| Version | Changes |
|---------|---------|
| v0.01   | Initial protocol (GET_CONF, CONF_DATA only) |
| v0.02   | Added VAR_DATA, SET_INPUT |
| v0.03   | Added reliability (ACK, VAR_UPDATE) |
| v2.0    | Added META_DATA, TELEMETRY, expanded to 256 widgets, aspect ratio support |
| v3.0    | Current version — META_UPDATE, enhanced reliability, 8-bit addressing for 256 widgets |