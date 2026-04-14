/**
 * RadioKitConfig.h
 * Library-wide constants, enums, and helpers for RadioKit.
 *
 * This header does NOT contain sketch-level macros.
 * Include RadioKit.h in your sketch.
 */

#ifndef RADIOKIT_CONFIG_H
#define RADIOKIT_CONFIG_H

#include <Arduino.h>
#include <stdint.h>

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
//  Widget type IDs (protocol)
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
//  LED color constants and enum
// ─────────────────────────────────────────────
enum RadioKit_LEDColor : uint8_t {
    RK_LED_OFF    = 0,
    RK_LED_RED    = 1,
    RK_LED_GREEN  = 2,
    RK_LED_BLUE   = 3,
    RK_LED_YELLOW = 4
};

// ─────────────────────────────────────────────
//  Rotation helper: user degrees (-180..+180) -> int8_t wire value
//  2-degree resolution: stored = round(deg / 2)
// ─────────────────────────────────────────────
#define RK_ROT(deg) ((int8_t)(((int16_t)(deg) < -180 ? -180 \
                              : (int16_t)(deg) >  180 ?  180 \
                              : (int16_t)(deg)) / 2))

#endif // RADIOKIT_CONFIG_H
