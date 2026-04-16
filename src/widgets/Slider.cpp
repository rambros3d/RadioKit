#include "Slider.h"

RK_Slider::RK_Slider(RK_SliderProps p) : props(p) {
    typeId = RK_TYPE_SLIDER;
    _init(p.label, p.x, p.y, p.scale, p.aspect, 0, p.variant,
          nullptr, nullptr, nullptr, p.rotation);
    props.value = p.value;
}

void RK_Slider::deserializeInput(const uint8_t* buf) {
    props.value = buf[0] > 100 ? 100 : buf[0];
}

void RK_Slider::serializeInput(uint8_t* buf) const {
    buf[0] = props.value;
}
