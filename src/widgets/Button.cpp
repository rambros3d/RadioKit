#include "Button.h"

RadioKit_Button::RadioKit_Button()
    : _state(false), _pendingPress(false)
{
    typeId = RADIOKIT_TYPE_BUTTON;
}

void RadioKit_Button::serializeInput(uint8_t* buf) const {
    buf[0] = _state ? 1 : 0;
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    if (newState && !_state) {
        _pendingPress = true;
    }
    _state = newState;
}

bool RadioKit_Button::pressed() {
    if (_pendingPress) {
        _pendingPress = false;
        return true;
    }
    return false;
}
