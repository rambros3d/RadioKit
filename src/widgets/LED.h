#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

class RadioKit_LED : public RadioKit_Widget {
public:
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

#endif // RADIOKIT_WIDGET_LED_H
