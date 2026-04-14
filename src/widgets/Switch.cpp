#include "Switch.h"

RadioKit_Switch::RadioKit_Switch()
    : _state(false)
{
    typeId = RADIOKIT_TYPE_SWITCH;
}

void RadioKit_Switch::serializeInput(uint8_t* buf) const {
    buf[0] = _state ? 1 : 0;
}

void RadioKit_Switch::deserializeInput(const uint8_t* buf) {
    _state = (buf[0] != 0);
}
