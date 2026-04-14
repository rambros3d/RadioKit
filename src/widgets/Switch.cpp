#include "Switch.h"

RadioKit_Switch::RadioKit_Switch(const char* label, uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _state(false)
{
    typeId = RK_TYPE_SWITCH;
    _init(label, x, y, size, aspect);
}

RadioKit_Switch::RadioKit_Switch(uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _state(false)
{
    typeId = RK_TYPE_SWITCH;
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_Switch::deserializeInput(const uint8_t* buf) {
    _state = (buf[0] != 0);
}
