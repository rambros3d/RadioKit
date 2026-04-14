#include "Joystick.h"

RadioKit_Joystick::RadioKit_Joystick()
    : _x(0), _y(0)
{
    typeId = RADIOKIT_TYPE_JOYSTICK;
}

void RadioKit_Joystick::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)_x;
    buf[1] = (uint8_t)_y;
}

void RadioKit_Joystick::deserializeInput(const uint8_t* buf) {
    _x = (int8_t)buf[0];
    _y = (int8_t)buf[1];
}
