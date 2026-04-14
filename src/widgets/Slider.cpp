#include "Slider.h"

RadioKit_Slider::RadioKit_Slider()
    : _value(0)
{
    typeId = RADIOKIT_TYPE_SLIDER;
}

void RadioKit_Slider::serializeInput(uint8_t* buf) const {
    buf[0] = _value;
}

void RadioKit_Slider::deserializeInput(const uint8_t* buf) {
    _value = (buf[0] > 100) ? 100 : buf[0];
}
