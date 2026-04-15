/**
 * Joystick.h
 * RK_Joystick — 2-axis analog controller (-100 to +100).
 */

#ifndef RADIOKIT_WIDGET_JOYSTICK_H
#define RADIOKIT_WIDGET_JOYSTICK_H

#include "Widget.h"

// ── Props struct ─────────────────────────────────────────────
struct RK_JoystickProps {
    const char* label   = nullptr;
    uint8_t     x       = 0;
    uint8_t     y       = 0;
    float       scale   = 1.0f;
    int16_t     rotation = 0;
    bool        enabled = true;
    uint8_t     variant = 0;  // 0=self-centering, 1=no-centering
    int8_t      xvalue  = 0;
    int8_t      yvalue  = 0;
};

// ── Widget class ─────────────────────────────────────────────
class RK_Joystick : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 10; // 1.0

    RK_Joystick(RK_JoystickProps p);

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    int8_t getX() const { return props.xvalue; }
    int8_t getY() const { return props.yvalue; }

    RK_JoystickProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }
};

#endif // RADIOKIT_WIDGET_JOYSTICK_H
