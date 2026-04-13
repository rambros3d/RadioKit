/**
 * RadioKitWidgets.h
 * Widget type definitions and classes for RadioKit
 *
 * Each widget stores its layout, label, and current data values.
 * Input widgets (Button, Switch, Slider, Joystick) expose read methods.
 * Output widgets (LED, Text) expose write methods.
 */

#ifndef RADIOKIT_WIDGETS_H
#define RADIOKIT_WIDGETS_H

#include <Arduino.h>
#include <stdint.h>

// ─────────────────────────────────────────────
//  Widget type identifiers (matches protocol spec)
// ─────────────────────────────────────────────
#define RADIOKIT_TYPE_BUTTON   0x01
#define RADIOKIT_TYPE_SWITCH   0x02
#define RADIOKIT_TYPE_SLIDER   0x03
#define RADIOKIT_TYPE_JOYSTICK 0x04
#define RADIOKIT_TYPE_LED      0x05
#define RADIOKIT_TYPE_TEXT     0x06

// Maximum label length (bytes)
#define RADIOKIT_MAX_LABEL     32

// Maximum text display length (protocol TEXT output = 32 bytes, null-terminated)
#define RADIOKIT_TEXT_LEN      32

// Maximum number of widgets the library can manage
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
    // Set by RadioKit.addWidget()
    uint8_t  typeId;
    uint8_t  widgetId;
    uint16_t x, y, w, h;
    char     label[RADIOKIT_MAX_LABEL + 1]; // +1 for null terminator

    // Byte counts for protocol serialization
    virtual uint8_t inputSize()  const = 0;  // bytes this widget reads from SET_INPUT
    virtual uint8_t outputSize() const = 0;  // bytes this widget writes to VAR_DATA

    // Serialize/deserialize variable data
    virtual void serializeInput(uint8_t* buf)         const = 0;  // write current input state
    virtual void serializeOutput(uint8_t* buf)        const = 0;  // write current output state
    virtual void deserializeInput(const uint8_t* buf)       = 0;  // update from incoming input

    RadioKit_Widget() : typeId(0), widgetId(0), x(0), y(0), w(0), h(0) {
        label[0] = '\0';
    }

    virtual ~RadioKit_Widget() {}
};

// ─────────────────────────────────────────────
//  Button widget  (input: 1 byte, 0=released 1=pressed)
// ─────────────────────────────────────────────
class RadioKit_Button : public RadioKit_Widget {
public:
    RadioKit_Button();

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    // Returns true once per press event (auto-clears after read)
    bool pressed();

    // Raw state — true while button is held
    bool isHeld() const { return _state; }

private:
    bool _state;
    bool _pendingPress;
};

// ─────────────────────────────────────────────
//  Switch widget  (input: 1 byte, 0=OFF 1=ON)
// ─────────────────────────────────────────────
class RadioKit_Switch : public RadioKit_Widget {
public:
    RadioKit_Switch();

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    bool isOn() const { return _state; }

private:
    bool _state;
};

// ─────────────────────────────────────────────
//  Slider widget  (input: 1 byte, 0-100)
// ─────────────────────────────────────────────
class RadioKit_Slider : public RadioKit_Widget {
public:
    RadioKit_Slider();

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    // Returns 0–100
    uint8_t value() const { return _value; }

private:
    uint8_t _value;
};

// ─────────────────────────────────────────────
//  Joystick widget  (input: 2 bytes, int8_t X then int8_t Y, -100 to +100)
// ─────────────────────────────────────────────
class RadioKit_Joystick : public RadioKit_Widget {
public:
    RadioKit_Joystick();

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    int8_t x() const { return _x; }  // -100 to +100
    int8_t y() const { return _y; }  // -100 to +100

private:
    int8_t _x;
    int8_t _y;
};

// ─────────────────────────────────────────────
//  LED widget  (output: 1 byte, RadioKit_LEDColor)
// ─────────────────────────────────────────────
class RadioKit_LED : public RadioKit_Widget {
public:
    // Expose color constants on the class for user convenience
    static const RadioKit_LEDColor OFF    = LED_OFF;
    static const RadioKit_LEDColor RED    = LED_RED;
    static const RadioKit_LEDColor GREEN  = LED_GREEN;
    static const RadioKit_LEDColor BLUE   = LED_BLUE;
    static const RadioKit_LEDColor YELLOW = LED_YELLOW;

    RadioKit_LED();

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 1; }

    void serializeInput(uint8_t* buf)        const override {}
    void serializeOutput(uint8_t* buf)       const override;
    void deserializeInput(const uint8_t* buf)      override {}

    void set(RadioKit_LEDColor color) { _color = color; }
    RadioKit_LEDColor get() const { return _color; }

private:
    RadioKit_LEDColor _color;
};

// ─────────────────────────────────────────────
//  Text widget  (output: 32 bytes, null-terminated string)
// ─────────────────────────────────────────────
class RadioKit_Text : public RadioKit_Widget {
public:
    RadioKit_Text();

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return RADIOKIT_TEXT_LEN; }

    void serializeInput(uint8_t* buf)        const override {}
    void serializeOutput(uint8_t* buf)       const override;
    void deserializeInput(const uint8_t* buf)      override {}

    // Set display text (truncated to 31 chars + null)
    void set(const char* text);
    void set(const String& text) { set(text.c_str()); }

    const char* get() const { return _text; }

private:
    char _text[RADIOKIT_TEXT_LEN];
};

#endif // RADIOKIT_WIDGETS_H
