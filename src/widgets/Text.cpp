#include "Text.h"
#include <string.h>

RadioKit_Text::RadioKit_Text() {
    typeId = RADIOKIT_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
}

void RadioKit_Text::set(const char* text) {
    if (!text) {
        memset(_text, 0, RADIOKIT_TEXT_LEN);
        return;
    }
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
}

void RadioKit_Text::serializeOutput(uint8_t* buf) const {
    memset(buf, 0, RADIOKIT_TEXT_LEN);
    strncpy((char*)buf, _text, RADIOKIT_TEXT_LEN - 1);
}
