/**
 * Button.h
 * RK_PushButton  — momentary (true while held)
 * RK_ToggleButton — latched (toggles on tap)
 */

#ifndef RADIOKIT_WIDGET_BUTTON_H
#define RADIOKIT_WIDGET_BUTTON_H

#include "Widget.h"
#include <initializer_list>

// ── Props struct ───────────────────────────────────────────────────────
struct RK_ButtonProps {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t x = 0;
  uint8_t y = 0;
  int16_t rotation = 0; ///< Rotation in degrees. Positive = clockwise.
  float scale = 1.0f;
  uint8_t style = 0;
  bool state = false;
  const char *onText = nullptr;
  const char *offText = nullptr;
};

// ── Shared implementation base ──────────────────────────────────────────────
class RadioKit_Button : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 10;

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 1; }
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t* buf)        override;

    bool get() const { return props.state; }
    void set(bool val) { props.state = val; }
    void setIcon(const char* val);

    RK_ButtonProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }
    bool    _pendingPress = false;

    void _initFromProps(const RK_ButtonProps& p, uint8_t typeId);
};

// ── PushButton ─────────────────────────────────────────────────────────────
class RK_PushButton : public RadioKit_Button {
public:
    RK_PushButton(RK_ButtonProps p);
    bool isPressed();
};

// ── ToggleButton ────────────────────────────────────────────────────────────
class RK_ToggleButton : public RadioKit_Button {
public:
    RK_ToggleButton(RK_ButtonProps p);
};

#endif // RADIOKIT_WIDGET_BUTTON_H
