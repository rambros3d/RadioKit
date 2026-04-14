#ifndef RADIOKIT_WIDGET_TEXT_H
#define RADIOKIT_WIDGET_TEXT_H

#include "Widget.h"

class RadioKit_Text : public RadioKit_Widget {
public:
    static constexpr float DEFAULT_ASPECT = 4.0f;

    RadioKit_Text(const char* label, uint8_t x, uint8_t y,
                  uint8_t size, float aspect = 0);
    RadioKit_Text(uint8_t x, uint8_t y,
                  uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return RADIOKIT_TEXT_LEN; }
    void serializeOutput(uint8_t* buf)        const override;
    void deserializeInput(const uint8_t*)           override {}

    void        set(const char* text);
    void        set(const String& text) { set(text.c_str()); }
    const char* get() const             { return _text; }

protected:
    float defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    char _text[RADIOKIT_TEXT_LEN];
};

#endif // RADIOKIT_WIDGET_TEXT_H
