#ifndef RADIOKIT_WIDGET_JOYSTICK_H
#define RADIOKIT_WIDGET_JOYSTICK_H

#include "Widget.h"

class RadioKit_Joystick : public RadioKit_Widget {
public:
    // 1.0 ×10 = 10
    static constexpr uint8_t DEFAULT_ASPECT = 10;

    RadioKit_Joystick(const char* label, uint8_t x, uint8_t y,
                      uint8_t size, float aspect = 0);
    RadioKit_Joystick(uint8_t x, uint8_t y,
                      uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    int8_t getX() const { return _jx; }
    int8_t getY() const { return _jy; }

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    int8_t _jx;
    int8_t _jy;
};

#endif
