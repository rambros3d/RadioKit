#include "LED.h"

RadioKit_LED::RadioKit_LED(const char* label, uint8_t x, uint8_t y,
                           uint8_t size, float aspect)
    : _color(RK_LED_OFF)
{
    typeId = RK_TYPE_LED;
    _init(label, x, y, size, aspect);
}

RadioKit_LED::RadioKit_LED(uint8_t x, uint8_t y,
                           uint8_t size, float aspect)
    : _color(RK_LED_OFF)
{
    typeId = RK_TYPE_LED;
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = (uint8_t)_color;
}
