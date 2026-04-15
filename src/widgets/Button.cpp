#include "Button.h"
#include <string.h>

void RadioKit_Button::_initFromProps(const RK_ButtonProps& p, uint8_t tid) {
    props  = p;
    typeId = tid;
    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, 0,
          p.icon, p.onText, p.offText, p.rotation);
}

void RadioKit_Button::serializeOutput(uint8_t* buf) const {
    buf[0] = props.state ? 1 : 0;
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    if (typeId == RK_TYPE_PUSH_BUTTON) {
        if (newState && !props.state) _pendingPress = true;
        props.state = newState;
    } else {
        props.state = newState;
    }
}

void RadioKit_Button::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
}

RK_PushButton::RK_PushButton(RK_ButtonProps p) {
    _initFromProps(p, RK_TYPE_PUSH_BUTTON);
}

bool RK_PushButton::isPressed() {
    if (_pendingPress) { _pendingPress = false; return true; }
    return false;
}

RK_ToggleButton::RK_ToggleButton(RK_ButtonProps p) {
    _initFromProps(p, RK_TYPE_TOGGLE_BUTTON);
    props.state = p.state;
}
