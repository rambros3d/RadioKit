/**
 * LED.h
 * RK_LED — visual status indicator (Arduino → App).
 * Uses RGB + opacity instead of the old color enum.
 */

#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

// ── Props struct ─────────────────────────────────────────────
struct RK_LEDProps {
    const char* label   = nullptr;
    const char* icon    = nullptr;
    uint8_t     x       = 0;
    uint8_t     y       = 0;
    float       scale   = 1.0f;
    uint8_t     style   = 0;
    bool        state   = false;
    uint8_t     red     = 255;
    uint8_t     green   = 0;
    uint8_t     blue    = 0;
    uint8_t     opacity = 255;
};

// ── Widget class ─────────────────────────────────────────────
class RK_LED : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 10; // 1.0

    RK_LED(RK_LEDProps p);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 5; } // state + R + G + B + opacity
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    void on()  { props.state = true;  }
    void off() { props.state = false; }

    /** Accepts 6-char (RRGGBB) or 8-char (RRGGBBAA) hex string. */
    void setColor(const char* hex);
    /** Accepts 0xRRGGBB or 0xRRGGBBAA uint32. */
    void setColor(uint32_t rgba);

    void setOpacity(uint8_t val)  { props.opacity = val; }
    void setRed(uint8_t val)      { props.red     = val; }
    void setGreen(uint8_t val)    { props.green   = val; }
    void setBlue(uint8_t val)     { props.blue    = val; }
    void setIcon(const char* val);

    RK_LEDProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }
};

#endif // RADIOKIT_WIDGET_LED_H
