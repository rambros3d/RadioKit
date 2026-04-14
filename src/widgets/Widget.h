/**
 * Widget.h
 * Base class and constants for RadioKit widgets.
 */

#ifndef RADIOKIT_WIDGET_BASE_H
#define RADIOKIT_WIDGET_BASE_H

#include <Arduino.h>
#include <stdint.h>

// ─────────────────────────────────────────────
//  Widget type identifiers
// ─────────────────────────────────────────────
#define RADIOKIT_TYPE_BUTTON   0x01
#define RADIOKIT_TYPE_SWITCH   0x02
#define RADIOKIT_TYPE_SLIDER   0x03
#define RADIOKIT_TYPE_JOYSTICK 0x04
#define RADIOKIT_TYPE_LED      0x05
#define RADIOKIT_TYPE_TEXT     0x06

// Maximum label length
#define RADIOKIT_MAX_LABEL     32

// Maximum text display length
#define RADIOKIT_TEXT_LEN      32

// Maximum number of widgets
#define RADIOKIT_MAX_WIDGETS   16

// ─────────────────────────────────────────────
//  LED color constants
// ─────────────────────────────────────────────
enum RadioKit_LEDColor : uint8_t {
    LED_OFF    = 0,
    LED_RED    = 1,
    LED_GREEN  = 2,
    LED_BLUE   = 3,
    LED_YELLOW = 4
};

// ─────────────────────────────────────────────
//  Base widget class
// ─────────────────────────────────────────────
class RadioKit_Widget {
public:
    uint8_t  typeId;
    uint8_t  widgetId;
    uint16_t x, y, w, h;
    char     label[RADIOKIT_MAX_LABEL + 1];

    virtual uint8_t inputSize()  const = 0;
    virtual uint8_t outputSize() const = 0;

    virtual void serializeInput(uint8_t* buf)         const = 0;
    virtual void serializeOutput(uint8_t* buf)        const = 0;
    virtual void deserializeInput(const uint8_t* buf)       = 0;

    RadioKit_Widget() : typeId(0), widgetId(0), x(0), y(0), w(0), h(0) {
        label[0] = '\0';
    }

    virtual ~RadioKit_Widget() {}
};

#endif // RADIOKIT_WIDGET_BASE_H
