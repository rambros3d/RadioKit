#include "Joystick.h"

RK_Joystick::RK_Joystick(RK_JoystickProps p)
    : props(p)
{
    typeId    = RK_TYPE_JOYSTICK;
    _rotation = p.rotation;
    _enabled  = p.enabled;
    _init(p.label, p.x, p.y, p.scale, 0.0f, 0, p.variant,
          nullptr, nullptr, nullptr);
    // Restore rotation & enabled after _init (which resets them)
    _rotation = p.rotation;
    _enabled  = p.enabled;
}

void RK_Joystick::deserializeInput(const uint8_t* buf) {
    props.xvalue = (int8_t)buf[0];
    props.yvalue = (int8_t)buf[1];
}
