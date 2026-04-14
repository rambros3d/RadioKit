#ifndef RADIOKIT_WIDGET_BUTTON_H
#define RADIOKIT_WIDGET_BUTTON_H

#include "Widget.h"

class RadioKit_Button : public RadioKit_Widget {
public:
    static constexpr float DEFAULT_ASPECT = 2.5f;

    RadioKit_Button(const char* label, uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);
    RadioKit_Button(uint8_t x, uint8_t y,
                    uint8_t size, float aspect = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)          const override {}
    void deserializeInput(const uint8_t* buf)     override;

    /// True once on the leading edge of a press (auto-clears on read)
    bool isPressed();
    /// True continuously while button is held
    bool isHeld() const { return _state; }

protected:
    float defaultAspect() const override { return DEFAULT_ASPECT; }

private:
    bool _state;
    bool _pendingPress;
};

#endif // RADIOKIT_WIDGET_BUTTON_H
