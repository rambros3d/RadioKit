/**
 * Slider.h
 * RK_Slider — analog input (0–100).
 */

#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#include "Widget.h"

struct RK_SliderProps {
    const char* label   = nullptr;
    uint8_t     x       = 0;
    uint8_t     y       = 0;
    float       scale   = 1.0f;
    float       aspect  = 1.0f;
    uint8_t     variant = 0;
    uint8_t     value   = 0;
    int16_t     rotation = 0;  ///< Rotation in degrees.
};

class RK_Slider : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 50;

    RK_Slider(RK_SliderProps p);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    uint8_t get() const { return props.value; }
    void    set(uint8_t val) { props.value = val > 100 ? 100 : val; }

    RK_SliderProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }
};

#endif // RADIOKIT_WIDGET_SLIDER_H
