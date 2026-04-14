#include "Text.h"
#include <string.h>

RadioKit_Text::RadioKit_Text(const char* label, uint8_t x, uint8_t y,
                             uint8_t size, float aspect)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    _init(label, x, y, size, aspect);
}

RadioKit_Text::RadioKit_Text(uint8_t x, uint8_t y,
                             uint8_t size, float aspect)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    _init(nullptr, x, y, size, aspect);
}

void RadioKit_Text::set(const char* text) {
    if (!text) { memset(_text, 0, RADIOKIT_TEXT_LEN); return; }
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
}

void RadioKit_Text::serializeOutput(uint8_t* buf) const {
    memset(buf, 0, RADIOKIT_TEXT_LEN);
    strncpy((char*)buf, _text, RADIOKIT_TEXT_LEN - 1);
}
