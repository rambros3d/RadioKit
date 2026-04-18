# RadioKit Library - Functions Reference

> This document reflects the **v2.0 Object-Oriented API** using **Tailored Initializers**.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [RadioKit (Main Object)](#2-radiokit-main-object)
3. [Widgets Reference (Composition & Classes)](WIDGETS.md)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a simple three-part pattern. 

```cpp
#include <RadioKit.h>

// ── 1. Widget declarations (global scope) ────────────────────────────────
RK_PushButton fireBtn({ .label="Fire", .x=20, .y=50, .scale=1.5, .icon="flame" });

// ── 2. setup() ───────────────────────────────────────────────────────────
void setup() {
    RadioKit.config.name = "GP7 Locomotive";
    RadioKit.config.password = "1234";
    RadioKit.config.theme = "retro"; // Controller skin name or GitHub URL
    RadioKit.begin();
    RadioKit.startBLE("Train_01");
}

// ── 3. loop() ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
}
```

---

## 2. RadioKit (Main Object)

### `begin()`

Commits and synchronizes configuration. Must be called in `setup()`.

```cpp
void begin();
```

### `config` (Object)

Global settings object.

#### User Configurable


| Field             | Type          | Description                                                     |
| ----------------- | ------------- | --------------------------------------------------------------- |
| `**name**`        | `const char*` | Model or Device name. Sent to app on connection.                |
| `**password**`    | `const char*` | Optional connection password (leave empty for none).            |
| `**description**` | `const char*` | Short overview of the device's function.                        |
| `**version**`     | `const char*` | User-defined firmware version string (e.g. `"1.0.4"`).          |
| `**theme**`       | `const char*` | Controller skin identifier. Supports built-in names or GitHub URLs. See [UI Skins](UI_SKINS.md). |
| `**type**`        | `const char*` | Category of device (e.g. `"truck"`, `"robot"`, `"locomotive"`). |
| `**orientation**` | `uint8_t`     | `RK_LANDSCAPE` (Default) or `RK_PORTRAIT`.                      |
| `**width**`       | `uint8_t`     | Canvas width (0-250).                                           |
| `**height**`      | `uint8_t`     | Canvas height (0-250).                                          |


#### Read-Only (Set by Library)


| Field              | Type          | Description                                        |
| ------------------ | ------------- | -------------------------------------------------- |
| `**architecture**` | `uint8_t`     | Detected hardware platform (e.g. `RK_ARCH_ESP32`). |
| `**libversion**`   | `const char*` | Current RadioKit library version string.           |


## 5. Constants & Enums

### Architecture (`architecture`)

- `RK_ARCH_UNKNOWN` (0)
- `RK_ARCH_ESP32`   (1)
- `RK_ARCH_NORDIC`  (2)
- `RK_ARCH_SAMD`    (3)
- `RK_ARCH_STM32`   (4)