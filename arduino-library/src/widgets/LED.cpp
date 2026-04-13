#include "LED.h"
#include <string.h>

RK_LED::RK_LED(RK_LEDProps p) : props(p) {
    typeId = RK_TYPE_LED;
    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, 0,
          p.icon, nullptr, nullptr, p.rotation);
}

void RK_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = props.state   ? 1 : 0;
    buf[1] = props.red;
    buf[2] = props.green;
    buf[3] = props.blue;
    buf[4] = props.opacity;
}

void RK_LED::serializeInput(uint8_t* buf) const {
    // LEDs have no input state
}

void RK_LED::setColor(const char* hex) {
    if (!hex || hex[0] == '\0') return;
    const char* p = (hex[0] == '#') ? hex + 1 : hex;
    uint32_t val = strtoul(p, nullptr, 16);
    if (strlen(p) == 6) {
        props.red   = (val >> 16) & 0xFF;
        props.green = (val >>  8) & 0xFF;
        props.blue  =  val        & 0xFF;
    } else if (strlen(p) == 8) {
        props.red     = (val >> 24) & 0xFF;
        props.green   = (val >> 16) & 0xFF;
        props.blue    = (val >>  8) & 0xFF;
        props.opacity =  val        & 0xFF;
    }
}

void RK_LED::setColor(uint32_t rgba) {
    props.red     = (rgba >> 24) & 0xFF;
    props.green   = (rgba >> 16) & 0xFF;
    props.blue    = (rgba >>  8) & 0xFF;
    props.opacity =  rgba        & 0xFF;
}

void RK_LED::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
}
