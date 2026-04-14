/**
 * RadioKitConfig.h
 * Compile-time config DSL for RadioKit.
 *
 * Usage in sketch:
 *
 *   RK_CONFIG_BEGIN(RK_LANDSCAPE)
 *       RK_BUTTON  (20,  50, 25, 20,  0, "Fire")
 *       RK_JOYSTICK(160, 50, 35, 35,  0, "Drive")
 *       RK_LED     (20,  20, 12, 12,  0, "Status")
 *       RK_TEXT    (100, 80, 70, 15,  0, "Sensor")
 *   RK_CONFIG_END
 *
 * Then declare a struct whose fields (inputs first, outputs after,
 * connect_flag last) match the widget order above.
 */

#ifndef RADIOKIT_CONFIG_H
#define RADIOKIT_CONFIG_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitProtocol.h"

// ─────────────────────────────────────────────
//  Canvas orientation
// ─────────────────────────────────────────────
enum RadioKit_Orientation : uint8_t {
    RK_LANDSCAPE = 0x00,   ///< Canvas: 200 wide × 100 tall
    RK_PORTRAIT  = 0x01    ///< Canvas: 100 wide × 200 tall
};

#define RK_CANVAS_LANDSCAPE_W  200
#define RK_CANVAS_LANDSCAPE_H  100
#define RK_CANVAS_PORTRAIT_W   100
#define RK_CANVAS_PORTRAIT_H   200

// ─────────────────────────────────────────────
//  Widget type IDs (internal / protocol)
// ─────────────────────────────────────────────
#define RK_TYPE_BUTTON   0x01
#define RK_TYPE_SWITCH   0x02
#define RK_TYPE_SLIDER   0x03
#define RK_TYPE_JOYSTICK 0x04
#define RK_TYPE_LED      0x05
#define RK_TYPE_TEXT     0x06

// ─────────────────────────────────────────────
//  Widget limits
// ─────────────────────────────────────────────
#define RADIOKIT_MAX_WIDGETS  16
#define RADIOKIT_MAX_LABEL    32
#define RADIOKIT_TEXT_LEN     32

// ─────────────────────────────────────────────
//  LED color constants
// ─────────────────────────────────────────────
#define RK_LED_OFF    0
#define RK_LED_RED    1
#define RK_LED_GREEN  2
#define RK_LED_BLUE   3
#define RK_LED_YELLOW 4

// ─────────────────────────────────────────────
//  Rotation helper: user degrees -> int8_t wire value
//  Clamps to [-180,+180] then divides by 2 for 2-degree resolution.
// ─────────────────────────────────────────────
#define RK_ROT(deg) ((int8_t)(((int16_t)(deg) < -180 ? -180 \
                              : (int16_t)(deg) >  180 ?  180 \
                              : (int16_t)(deg)) / 2))

// ─────────────────────────────────────────────
//  Config block macros
//
//  The config array layout:
//    [PROTO_VERSION][ORIENTATION][NUM_WIDGETS]
//    then per widget: [TYPE][X][Y][W][H][ROTATION][LABEL_LEN][LABEL...]
//
//  NUM_WIDGETS is patched at compile time by counting the widget
//  macro expansions. We use a two-pass approach: first pass emits
//  all bytes; the widget count byte at index 2 is computed via
//  a separate constexpr counter trick using __COUNTER__.
//
//  Simpler portable approach used here:
//  The user is responsible for the widget count matching the macros.
//  The library walks the array at runtime to count widgets.
//  We emit 0xFF as a sentinel for NUM_WIDGETS; begin() counts at init.
// ─────────────────────────────────────────────

/**
 * Open the config block and set orientation.
 * Emits the PROGMEM array header bytes.
 */
#define RK_CONFIG_BEGIN(orientation)                                        \
    static const uint8_t PROGMEM _rk_conf[] = {                            \
        RK_PROTOCOL_VERSION,                                                \
        (uint8_t)(orientation),                                             \
        0xFF, /* NUM_WIDGETS placeholder — filled by RadioKit.begin() */

/**
 * Emit bytes for a BUTTON widget.
 * Input struct field: uint8_t name;  (1=pressed, 0=released)
 */
#define RK_BUTTON(x, y, w, h, rot, label)                                   \
    RK_TYPE_BUTTON,                                                          \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/**
 * Emit bytes for a SWITCH widget.
 * Input struct field: uint8_t name;  (1=on, 0=off)
 */
#define RK_SWITCH(x, y, w, h, rot, label)                                   \
    RK_TYPE_SWITCH,                                                          \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/**
 * Emit bytes for a SLIDER widget.
 * Input struct field: uint8_t name;  (0–100)
 */
#define RK_SLIDER(x, y, w, h, rot, label)                                   \
    RK_TYPE_SLIDER,                                                          \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/**
 * Emit bytes for a JOYSTICK widget.
 * Input struct fields: int8_t nameX; int8_t nameY;  (each -100..+100)
 */
#define RK_JOYSTICK(x, y, w, h, rot, label)                                 \
    RK_TYPE_JOYSTICK,                                                        \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/**
 * Emit bytes for an LED output widget.
 * Output struct field: uint8_t name;  (RK_LED_OFF/RED/GREEN/BLUE/YELLOW)
 */
#define RK_LED(x, y, w, h, rot, label)                                      \
    RK_TYPE_LED,                                                             \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/**
 * Emit bytes for a TEXT output widget.
 * Output struct field: char name[32];  (null-terminated)
 */
#define RK_TEXT(x, y, w, h, rot, label)                                     \
    RK_TYPE_TEXT,                                                            \
    (uint8_t)(x), (uint8_t)(y), (uint8_t)(w), (uint8_t)(h),                \
    (uint8_t)RK_ROT(rot),                                                   \
    (uint8_t)(sizeof(label) - 1),                                           \
    label[0],  label[1],  label[2],  label[3],  label[4],  label[5],        \
    label[6],  label[7],  label[8],  label[9],  label[10], label[11],       \
    label[12], label[13], label[14], label[15], label[16], label[17],       \
    label[18], label[19], label[20], label[21], label[22], label[23],       \
    label[24], label[25], label[26], label[27], label[28], label[29],       \
    label[30], label[31],

/** Close the config block. */
#define RK_CONFIG_END  0xFF }; /* 0xFF = end sentinel */

// ─────────────────────────────────────────────
//  Edge-detection helper macro
//
//  Detects a rising edge (0→1) on a button field.
//  Declare a `uint8_t prev_X = 0;` alongside each button you want
//  one-shot behaviour on.
//
//  Usage:
//    uint8_t prev_fire = 0;
//    if (RK_RISING(rk.fire, prev_fire)) { /* fires once per press */ }
// ─────────────────────────────────────────────
#define RK_RISING(cur, prev) \
    (((cur) && !(prev)) ? ((prev) = 1, true) : ((prev) = (cur), false))

#endif // RADIOKIT_CONFIG_H
