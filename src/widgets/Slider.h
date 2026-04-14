#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#include "Widget.h"

class RadioKit_Slider : public RadioKit_Widget {
public:
    RadioKit_Slider();

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    uint8_t value() const { return _value; }

private:
    uint8_t _value;
};

#endif // RADIOKIT_WIDGET_SLIDER_H
