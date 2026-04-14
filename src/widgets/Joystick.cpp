#include "Joystick.h"

RadioKit_Joystick::RadioKit_Joystick(const char* label, uint8_t x, uint8_t y,
                                     uint8_t size, float aspect)
    : _jx(0), _jy(0)
{
    typeId = RK_TYPE_JOYSTICK;
    _init(label, x, y, size, aspect);
}

RadioKit_Joystick::RadioKit_Joystick(uint8_t x, uint8_t y,
                                     uint8_t size, float aspect)
    : _jx(0), _jy(0)
{
    typeId = RK_TYPE_JOYSTICK;
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_Joystick::deserializeInput(const uint8_t* buf) {
    _jx = (int8_t)buf[0];
    _jy = (int8_t)buf[1];
}
