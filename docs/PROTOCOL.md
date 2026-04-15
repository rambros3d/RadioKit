# RadioKit Protocol - v0x03

## Overview

RadioKit uses a compact binary protocol over BLE or USB Serial.  
All multi-byte integers are **little-endian**.

---

## Packet Structure

```
[START][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
  0x55    total      total
```


| Field     | Size | Description                              |
| --------- | ---- | ---------------------------------------- |
| `START`   | 1    | Always `0x55`                            |
| `LENGTH`  | 2    | Total packet length including all fields |
| `CMD`     | 1    | Command byte                             |
| `PAYLOAD` | 0–N  | Command-specific payload                 |
| `CRC`     | 2    | CRC-16/CCITT-FALSE over `CMD + PAYLOAD`  |


Minimum packet size: **6 bytes** (no payload).

---

## Command Bytes


| Value  | Name         | Direction     | Description                           |
| ------ | ------------ | ------------- | ------------------------------------- |
| `0x01` | `GET_CONF`   | App → Arduino | Request configuration descriptor      |
| `0x02` | `CONF_DATA`  | Arduino → App | Configuration descriptor response     |
| `0x03` | `GET_VARS`   | App → Arduino | Request current variable state        |
| `0x04` | `VAR_DATA`   | Arduino → App | Variable state response (Full Sync)   |
| `0x05` | `SET_INPUT`  | App → Arduino | Push input widget values              |
| `0x06` | `ACK`        | Both          | Acknowledge SET_INPUT or VAR_UPDATE   |
| `0x07` | `PING`       | App → Arduino | Connectivity check                    |
| `0x08` | `PONG`       | Arduino → App | Ping response                         |
| `0x09` | `VAR_UPDATE` | Arduino → App | Reliable push of a single widget state |


---

## CONF_DATA (Configuration)

Sent in response to `GET_CONF`.

### Global Header

```
[PROTO_03][THEME][ORIENTATION][NUM_WIDGETS][NAME_LEN][NAME...][PWD_LEN][PWD...]
```


| Field           | Type          | Description                                            |
| --------------- | ------------- | ------------------------------------------------------ |
| `PROTO_VERSION` | `uint8_t`     | Current: `0x03`                                        |
| `THEME`         | `uint8_t`     | Global UI Theme index (e.g., `RK_RETRO`).              |
| `ORIENTATION`   | `uint8_t`     | `0x00` = Landscape, `0x01` = Portrait                  |
| `NUM_WIDGETS`   | `uint8_t`     | Number of widget descriptors that follow               |
| `NAME_LEN`      | `uint8_t`     | Length of device name string.                          |
| `NAME`          | `char[N]`     | Device identity name (UTF-8).                          |
| `PWD_LEN`       | `uint8_t`     | Length of password string.                             |
| `PWD`           | `char[N]`     | Plaintext identity password (UTF-8).                   |


### Widget Descriptor

```
[TYPE][ID][X][Y][SCALE][ASPECT][ROTATION][STYLE][VARIANT][STR_MASK][STR_DATA...]
```


| Field      | Type      | Description                                               |
| ---------- | --------- | --------------------------------------------------------- |
| `TYPE`     | `uint8_t` | Widget type ID (see table below).                         |
| `ID`       | `uint8_t` | Widget index (0-based, sequential).                       |
| `X`        | `uint8_t` | Center X on virtual canvas (0–250).                       |
| `Y`        | `uint8_t` | Center Y on virtual canvas (0–250).                       |
| `SCALE`    | `uint8_t` | Scale ×10 (e.g., `15` = 1.5×).                            |
| `ASPECT`   | `uint8_t` | Aspect ratio ×10 (e.g., `25` = 2.5).                      |
| `ROTATION` | `int16_t` | Rotation in degrees.                                      |
| `STYLE`    | `uint8_t` | Semantic visual index (Primary, Danger, etc.).            |
| `VARIANT`  | `uint8_t` | Behavioral variation index (e.g., Joystick centering).    |
| `STR_MASK` | `uint8_t` | **String Bitmask** (Determines following string segments). |


#### String Bitmask (`STR_MASK`)

Bits indicate which optional strings are included. Each active bit adds a `[LEN][STR]` pair to the `STR_DATA` block.

- `Bit 0`: **Label** (Primary display text)
- `Bit 1`: **Icon** (Standard name string)
- `Bit 2`: **OnText** (for Buttons)
- `Bit 3`: **OffText** (for Buttons)
- `Bit 4`: **Content** (for Text widget initial value)

---

## Runtime Communication

### VAR_DATA (Full Sync)

Contains the current state of all active widgets in ID order.

```
[DATA_W0][DATA_W1][DATA_W2]...
```

### VAR_UPDATE (Reliable Push)

Pushes a change for a single widget. Requires an `ACK` response from the App.

```
[SEQ][ID][DATA...]
```


| Field  | Type      | Description                              |
| ------ | --------- | ---------------------------------------- |
| `SEQ`  | `uint8_t` | Rolling sequence number.                 |
| `ID`   | `uint8_t` | The widget index.                        |
| `DATA` | `N bytes` | Runtime data (type-specific). See below. |


#### Reliability Logic
- The Arduino maintains a **1-slot pending queue**.
- Retransmission timeout: **200 ms**.
- **Fail-Soft Escalation**: If retransmission fails repeatedly (5 attempts), the Arduino must send a full **`VAR_DATA`** (Full Sync) packet to resynchronize the entire system.

### ACK (Confirmation)

Used to confirm receipt of `0x05 (SET_INPUT)` or `0x09 (VAR_UPDATE)`.

```
[SEQ]
```


| `TYPE` | Widget       | Data Bytes                             |
| ------ | ------------ | -------------------------------------- |
| `0x01` | PushButton   | 1 (`bool`)                             |
| `0x02` | ToggleButton | 1 (`bool`)                             |
| `0x03` | Slider       | 1 (0–100)                              |
| `0x04` | Joystick     | 2 (X, Y)                               |
| `0x05` | LED          | 5 ($1$ State, $3$ RGB, $1$ Opacity)    |
| `0x06` | Text         | 32 (`char[32]`, null-padded)           |

---

## Transports

### BLE

| Role           | UUID                                     |
| :------------- | :--------------------------------------- |
| **Service**    | `ad10ad10-4d10-4b1e-8a00-7ad10bad10a0` |
| **Characteristic** | `ad10ad11-4d10-4b1e-8a00-7ad10bad10a0` |

- **Design Note**: Using a dedicated 128-bit UUID prevents accidental connections from generic BLE terminal apps and ensures a clean discovery phase for the RadioKit mobile app.
- Packets fragmented into 20-byte MTU chunks.
- Handled by NimBLE-Arduino for reliability.

### USB Serial

- **Connection timeout:** `3000 ms` after the last valid packet.
- Recommended app PING interval: `1000 ms`.