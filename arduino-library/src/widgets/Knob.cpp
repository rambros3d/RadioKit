#include "Knob.h"

RK_Knob::RK_Knob(RK_KnobProps p) : props(p) {
    typeId = RK_TYPE_KNOB;
    uint8_t v = RK_VARIANT(p.centering, p.detents);
    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, v,
          p.icon, nullptr, nullptr, 0);
    props.value = p.value;
}

void RK_Knob::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    props.value = v > 100 ? 100 : (v < -100 ? -100 : v);
}

void RK_Knob::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)props.value; // two's complement, safe cast
}
