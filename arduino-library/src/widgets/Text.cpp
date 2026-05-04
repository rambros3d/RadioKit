#include "Text.h"
#include "../RadioKit.h"
#include <string.h>

RK_Text::RK_Text(RK_TextProps p)
    : props(p)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    if (p.text && p.text[0] != '\0') {
        strncpy(_text, p.text, RADIOKIT_TEXT_LEN - 1);
    }
    _init(p.label, p.x, p.y, p.height, p.width, p.style, 0,
          p.icon, nullptr, nullptr, p.rotation);
}

void RK_Text::set(const char* text) {
    if (!text) { memset(_text, 0, RADIOKIT_TEXT_LEN); return; }
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
    props.text = _text;
    RadioKit.pushUpdate(widgetId);
}

void RK_Text::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
    RadioKit.pushMetaUpdate(widgetId);
}

void RK_Text::serializeInput(uint8_t* buf) const {
    // Text widgets have no input state
}

void RK_Text::serializeOutput(uint8_t* buf) const {
  uint8_t len = (uint8_t)strlen(_text);
  buf[0] = len;
  if (len > 0) {
    memcpy(buf + 1, _text, len);
  }
}

uint8_t RK_Text::outputSize() const {
  return RADIOKIT_TEXT_LEN;
}
