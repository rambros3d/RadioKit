#include "Text.h"
#include <string.h>

RK_Text::RK_Text(RK_TextProps p)
    : props(p)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    if (p.text && p.text[0] != '\0') {
        strncpy(_text, p.text, RADIOKIT_TEXT_LEN - 1);
    }
    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, 0,
          p.icon, nullptr, nullptr, p.rotation);
}

void RK_Text::set(const char* text) {
    if (!text) { memset(_text, 0, RADIOKIT_TEXT_LEN); return; }
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
    props.text = _text;
}

void RK_Text::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
}

void RK_Text::serializeOutput(uint8_t* buf) const {
    memset(buf, 0, RADIOKIT_TEXT_LEN);
    strncpy((char*)buf, _text, RADIOKIT_TEXT_LEN - 1);
}
