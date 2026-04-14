#ifndef RADIOKIT_WIDGET_SWITCH_H
#define RADIOKIT_WIDGET_SWITCH_H

#include "Widget.h"

class RadioKit_Switch : public RadioKit_Widget {
public:
    // 1.6 ×10 = 16
    static constexpr uint8_t DEFAULT_ASPECT = 16;

    RadioKit_Switch(const char* label, uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);
    RadioKit_Switch(uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    bool isOn() const { return _state; }

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    bool _state;
};

#endif
