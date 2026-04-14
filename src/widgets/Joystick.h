#ifndef RADIOKIT_WIDGET_JOYSTICK_H
#define RADIOKIT_WIDGET_JOYSTICK_H

#include "Widget.h"

class RadioKit_Joystick : public RadioKit_Widget {
public:
    RadioKit_Joystick();

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    int8_t x() const { return _x; }
    int8_t y() const { return _y; }

private:
    int8_t _x;
    int8_t _y;
};

#endif // RADIOKIT_WIDGET_JOYSTICK_H
