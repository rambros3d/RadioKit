# RadioKit Binary Protocol Specification v1.0

## Overview
RadioKit uses a simple binary protocol over BLE (UART service) to exchange UI configuration and variable data between an Arduino device and a Flutter app.

**BLE Service UUID:** `0000FFE0-0000-1000-8000-00805F9B34FB`
**BLE Characteristic UUID:** `0000FFE1-0000-1000-8000-00805F9B34FB`

## Packet Format

All packets share this structure:

```
[START] [LENGTH_LO] [LENGTH_HI] [CMD] [PAYLOAD...] [CRC_LO] [CRC_HI]
```

| Field      | Size    | Description                                      |
|------------|---------|--------------------------------------------------|
| START      | 1 byte  | Always `0x55`                                    |
| LENGTH     | 2 bytes | Total packet length (little-endian), including header + CRC |
| CMD        | 1 byte  | Command identifier                               |
| PAYLOAD    | N bytes | Command-specific data                            |
| CRC        | 2 bytes | CRC-16/CCITT over CMD + PAYLOAD (little-endian)  |

**Minimum packet size:** 6 bytes (start + length + cmd + crc, no payload)

## CRC-16 Calculation

CRC-16/CCITT (poly 0x1021, init 0xFFFF) computed over CMD + PAYLOAD bytes.

## Commands

| CMD  | Name        | Direction       | Description                         |
|------|-------------|-----------------|-------------------------------------|
| 0x01 | GET_CONF    | App → Arduino   | Request UI configuration            |
| 0x02 | CONF_DATA   | Arduino → App   | UI configuration response           |
| 0x03 | GET_VARS    | App → Arduino   | Request current variable values     |
| 0x04 | VAR_DATA    | Arduino → App   | Current variable values             |
| 0x05 | SET_INPUT   | App → Arduino   | Set input variable values           |
| 0x06 | ACK         | Arduino → App   | Acknowledgment                      |
| 0x07 | PING        | App → Arduino   | Keep-alive ping                     |
| 0x08 | PONG        | Arduino → App   | Keep-alive pong                     |

## Widget Types

| Type ID | Name    | Input Size | Output Size | Description                    |
|---------|---------|------------|-------------|--------------------------------|
| 0x01    | BUTTON  | 1 byte     | 0           | Momentary push (1=pressed, 0=released) |
| 0x02    | SWITCH  | 1 byte     | 0           | Toggle (1=ON, 0=OFF)          |
| 0x03    | SLIDER  | 1 byte     | 0           | Linear 0–100                   |
| 0x04    | JOYSTICK| 2 bytes    | 0           | X,Y each int8_t (-100 to +100)|
| 0x05    | LED     | 0          | 1 byte      | LED color state (0=off, 1=red, 2=green, 3=blue, 4=yellow) |
| 0x06    | TEXT    | 0          | 32 bytes    | Null-terminated string display |

## CONF_DATA Payload Format

```
[PROTOCOL_VERSION] [NUM_WIDGETS] [WIDGET_1] [WIDGET_2] ... [WIDGET_N]
```

| Field             | Size   | Description                          |
|-------------------|--------|--------------------------------------|
| PROTOCOL_VERSION  | 1 byte | Currently 0x01                       |
| NUM_WIDGETS       | 1 byte | Number of widgets (max 255)          |

Each widget descriptor:
```
[TYPE_ID] [WIDGET_ID] [X] [Y] [W] [H] [LABEL_LEN] [LABEL...]
```

| Field     | Size    | Description                              |
|-----------|---------|------------------------------------------|
| TYPE_ID   | 1 byte  | Widget type (see table above)            |
| WIDGET_ID | 1 byte  | Unique widget ID (0-255)                 |
| X         | 2 bytes | X position (0-1000, LE)                  |
| Y         | 2 bytes | Y position (0-1000, LE)                  |
| W         | 2 bytes | Width (0-1000, LE)                       |
| H         | 2 bytes | Height (0-1000, LE)                      |
| LABEL_LEN | 1 byte  | Length of label string                    |
| LABEL     | N bytes | UTF-8 label (no null terminator)         |

Position/size uses a virtual 1000x1000 coordinate system. The app scales to actual screen size.

## VAR_DATA Payload Format

Variables are packed sequentially in widget registration order:

```
[INPUT_VARS...] [OUTPUT_VARS...]
```

- Input variables first (all widgets that have input, in order of widget ID)
- Output variables after (all widgets that have output, in order of widget ID)
- Sizes per widget type as defined in the widget table above

## SET_INPUT Payload Format

Same layout as the input portion of VAR_DATA. The app sends all input variable values at once.

## Connection Flow

1. App scans for BLE devices advertising the RadioKit service UUID
2. App connects and discovers the UART characteristic
3. App sends `GET_CONF` to request UI configuration
4. Arduino responds with `CONF_DATA` containing all widget descriptors
5. App renders the UI based on the configuration
6. App enters polling loop:
   - Sends `GET_VARS` every ~100ms
   - Receives `VAR_DATA` with current input+output values
   - When user interacts with a widget, sends `SET_INPUT` with updated input values
   - Arduino responds with `ACK`
7. Periodic `PING`/`PONG` for connection health (every 2s)
