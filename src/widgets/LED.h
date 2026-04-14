#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

class RadioKit_LED : public RadioKit_Widget {
public:
    static constexpr float DEFAULT_ASPECT = 1.0f;

    // Colour constants accessible as RadioKit_LED::GREEN etc.
    static const RadioKit_LEDColor OFF    = RK_LED_OFF;
    static const RadioKit_LEDColor RED    = RK_LED_RED;
    static const RadioKit_LEDColor GREEN  = RK_LED_GREEN;
    static const RadioKit_LEDColor BLUE   = RK_LED_BLUE;
    static const RadioKit_LEDColor YELLOW = RK_LED_YELLOW;

    RadioKit_LED(const char* label, uint8_t x, uint8_t y,
                 uint8_t size, float aspect = 0);
    RadioKit_LED(uint8_t x, uint8_t y,
                 uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 1; }
    void serializeOutput(uint8_t* buf)        const override;
    void deserializeInput(const uint8_t*)           override {}

    void              set(RadioKit_LEDColor color) { _color = color; }
    RadioKit_LEDColor get() const                  { return _color; }

protected:
    float defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    RadioKit_LEDColor _color;
};

#endif // RADIOKIT_WIDGET_LED_H
