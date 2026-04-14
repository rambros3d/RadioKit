#include "Slider.h"

RadioKit_Slider::RadioKit_Slider(const char* label, uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _value(0)
{
    typeId = RK_TYPE_SLIDER;
    _init(label, x, y, size, aspect);
}

RadioKit_Slider::RadioKit_Slider(uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _value(0)
{
    typeId = RK_TYPE_SLIDER;
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_Slider::deserializeInput(const uint8_t* buf) {
    _value = buf[0] > 100 ? 100 : buf[0];
}
