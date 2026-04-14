#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#include "Widget.h"

class RadioKit_Slider : public RadioKit_Widget {
public:
    // 5.0 ×10 = 50
    static constexpr uint8_t DEFAULT_ASPECT = 50;

    RadioKit_Slider(const char* label, uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);
    RadioKit_Slider(uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    uint8_t value() const { return _value; }

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    uint8_t _value;
};

#endif
