/**
 * Slider.h
 * RK_Slider — linear analog control (-100 to +100).
 *
 * variant byte: RK_VARIANT(centering, detents)
 *   bits[1:0] = centering  (RK_CENTER_NONE / LEFT / CENTER / RIGHT)
 *   bits[7:2] = detents    (0 = continuous, 1-63 = snap positions)
 */

#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#include "Widget.h"

struct RK_SliderProps {
  const char* label     = nullptr;
  uint8_t     x         = 0;
  uint8_t     y         = 0;
  int16_t     rotation  = 0;    ///< Rotation in degrees.
  float       scale     = 1.0f;
  float       aspect    = 1.0f;
  uint8_t     centering = RK_CENTER_NONE; ///< RK_CENTER_NONE/LEFT/CENTER/RIGHT
  uint8_t     detents   = 0;             ///< 0 = continuous; 1-63 = snap positions
  int8_t      value     = 0;             ///< Initial value: -100 to +100
};

class RK_Slider : public RadioKit_Widget {
public:
  static constexpr uint8_t DEFAULT_ASPECT = 50; ///< 5.0 (wide)

  RK_Slider(RK_SliderProps p);

  uint8_t inputSize()  const override { return 1; }
  uint8_t outputSize() const override { return 0; }
  void serializeInput(uint8_t* buf)          const override;
  void serializeOutput(uint8_t*)             const override {}
  void deserializeInput(const uint8_t* buf)        override;

  int8_t  get()           const { return props.value; }
  void    set(int8_t val)       { props.value = val > 100 ? 100 : (val < -100 ? -100 : val); }
  uint8_t centering()     const { return props.centering; }
  uint8_t detents()       const { return props.detents; }

  RK_SliderProps props;

protected:
  uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }
};

#endif // RADIOKIT_WIDGET_SLIDER_H
