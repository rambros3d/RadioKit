/**
 * RadioKitWidgets.cpp
 * Widget class implementations for RadioKit.
 */

#include "RadioKitWidgets.h"
#include <string.h>

// ─────────────────────────────────────────────
//  RadioKit_Button
// ─────────────────────────────────────────────
RadioKit_Button::RadioKit_Button()
    : _state(false), _pendingPress(false)
{
    typeId = RADIOKIT_TYPE_BUTTON;
}

void RadioKit_Button::serializeInput(uint8_t* buf) const {
    buf[0] = _state ? 1 : 0;
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    // Detect rising edge (released → pressed)
    if (newState && !_state) {
        _pendingPress = true;
    }
    _state = newState;
}

bool RadioKit_Button::pressed() {
    if (_pendingPress) {
        _pendingPress = false;
        return true;
    }
    return false;
}

// ─────────────────────────────────────────────
//  RadioKit_Switch
// ─────────────────────────────────────────────
RadioKit_Switch::RadioKit_Switch()
    : _state(false)
{
    typeId = RADIOKIT_TYPE_SWITCH;
}

void RadioKit_Switch::serializeInput(uint8_t* buf) const {
    buf[0] = _state ? 1 : 0;
}

void RadioKit_Switch::deserializeInput(const uint8_t* buf) {
    _state = (buf[0] != 0);
}

// ─────────────────────────────────────────────
//  RadioKit_Slider
// ─────────────────────────────────────────────
RadioKit_Slider::RadioKit_Slider()
    : _value(0)
{
    typeId = RADIOKIT_TYPE_SLIDER;
}

void RadioKit_Slider::serializeInput(uint8_t* buf) const {
    buf[0] = _value;
}

void RadioKit_Slider::deserializeInput(const uint8_t* buf) {
    // Clamp to 0-100
    _value = (buf[0] > 100) ? 100 : buf[0];
}

// ─────────────────────────────────────────────
//  RadioKit_Joystick
// ─────────────────────────────────────────────
RadioKit_Joystick::RadioKit_Joystick()
    : _x(0), _y(0)
{
    typeId = RADIOKIT_TYPE_JOYSTICK;
}

void RadioKit_Joystick::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)_x;
    buf[1] = (uint8_t)_y;
}

void RadioKit_Joystick::deserializeInput(const uint8_t* buf) {
    _x = (int8_t)buf[0];
    _y = (int8_t)buf[1];
}

// ─────────────────────────────────────────────
//  RadioKit_LED
// ─────────────────────────────────────────────
RadioKit_LED::RadioKit_LED()
    : _color(LED_OFF)
{
    typeId = RADIOKIT_TYPE_LED;
}

void RadioKit_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = (uint8_t)_color;
}

// ─────────────────────────────────────────────
//  RadioKit_Text
// ─────────────────────────────────────────────
RadioKit_Text::RadioKit_Text() {
    typeId = RADIOKIT_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
}

void RadioKit_Text::set(const char* text) {
    if (!text) {
        memset(_text, 0, RADIOKIT_TEXT_LEN);
        return;
    }
    // Copy at most RADIOKIT_TEXT_LEN-1 chars and ensure null termination
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
}

void RadioKit_Text::serializeOutput(uint8_t* buf) const {
    // Always write exactly RADIOKIT_TEXT_LEN bytes (null-padded)
    memset(buf, 0, RADIOKIT_TEXT_LEN);
    strncpy((char*)buf, _text, RADIOKIT_TEXT_LEN - 1);
}
