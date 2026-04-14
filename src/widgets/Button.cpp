#include "Button.h"

RadioKit_Button::RadioKit_Button(const char* label, uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _state(false), _pendingPress(false)
{
    typeId = RK_TYPE_BUTTON;
    _init(label, x, y, size, aspect);
}

RadioKit_Button::RadioKit_Button(uint8_t x, uint8_t y,
                                 uint8_t size, float aspect)
    : _state(false), _pendingPress(false)
{
    typeId = RK_TYPE_BUTTON;
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    if (newState && !_state) _pendingPress = true;
    _state = newState;
}

bool RadioKit_Button::isPressed() {
    if (_pendingPress) {
        _pendingPress = false;
        return true;
    }
    return false;
}
