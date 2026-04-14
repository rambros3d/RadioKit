#ifndef RADIOKIT_WIDGET_SWITCH_H
#define RADIOKIT_WIDGET_SWITCH_H

#include "Widget.h"

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

#endif // RADIOKIT_WIDGET_SWITCH_H
