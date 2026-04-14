#ifndef RADIOKIT_WIDGET_BUTTON_H
#define RADIOKIT_WIDGET_BUTTON_H

#include "Widget.h"

class RadioKit_Button : public RadioKit_Widget {
public:
    RadioKit_Button();

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }

    void serializeInput(uint8_t* buf)        const override;
    void serializeOutput(uint8_t* buf)       const override {}
    void deserializeInput(const uint8_t* buf)      override;

    bool pressed();
    bool isHeld() const { return _state; }

private:
    bool _state;
    bool _pendingPress;
};

#endif // RADIOKIT_WIDGET_BUTTON_H
