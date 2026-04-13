/**
 * LED.h
 * RK_LED — visual status indicator (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

struct RK_LEDProps {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t x = 0;
  uint8_t y = 0;
  int16_t rotation = 0; ///< Rotation in degrees.
  float scale = 1.0f;
  uint8_t style = 0;
  bool state = false;
  uint8_t red = 255;
  uint8_t green = 0;
  uint8_t blue = 0;
  uint8_t opacity = 255;
};

class RK_LED : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 10;

    RK_LED(RK_LEDProps p);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 5; } // STATE + R + G + B + OPACITY
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    void on()  { props.state = true;  }
    void off() { props.state = false; }

    void setColor(const char* hex);
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
