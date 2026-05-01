/**
 * Text.h
 * RK_Text — dynamic text display label (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_TEXT_H
#define RADIOKIT_WIDGET_TEXT_H

#include "Widget.h"

struct RK_TextProps {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t x = 0;
  uint8_t y = 0;
  int16_t rotation = 0; ///< Rotation in degrees.
  float scale = 1.0f;
  uint8_t style = 0;
  const char *text = nullptr;
};

class RK_Text : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 40;

    RK_Text(RK_TextProps p);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return (uint8_t)strlen(_text) + 1; }
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    void        set(const char* text);
    void        set(const String& s) { set(s.c_str()); }
    const char* get() const { return _text; }
    void        setIcon(const char* val);

    RK_TextProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    char _text[RADIOKIT_TEXT_LEN];
};

#endif // RADIOKIT_WIDGET_TEXT_H
