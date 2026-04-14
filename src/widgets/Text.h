#ifndef RADIOKIT_WIDGET_TEXT_H
#define RADIOKIT_WIDGET_TEXT_H

#include "Widget.h"

class RadioKit_Text : public RadioKit_Widget {
public:
    RadioKit_Text();

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return RADIOKIT_TEXT_LEN; }

    void serializeInput(uint8_t* buf)        const override {}
    void serializeOutput(uint8_t* buf)       const override;
    void deserializeInput(const uint8_t* buf)      override {}

    void set(const char* text);
    void set(const String& text) { set(text.c_str()); }

    const char* get() const { return _text; }

private:
    char _text[RADIOKIT_TEXT_LEN];
};

#endif // RADIOKIT_WIDGET_TEXT_H
