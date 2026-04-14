#include "Widget.h"
#include "../RadioKit.h"
#include <string.h>

RadioKit_Widget::RadioKit_Widget()
    : typeId(0), widgetId(0)
    , _x(0), _y(0), _size(0), _aspect(0)
    , _rotation(0), _visible(true)
{
    _label[0] = '\0';
}

// float aspect →0–2.55 mapped to uint8_t 0–255 via ×10
static uint8_t floatToAspect(float f) {
    if (f <= 0.0f) return 0;
    float v = f * 10.0f + 0.5f;
    return (v > 255.0f) ? 255 : (uint8_t)v;
}

void RadioKit_Widget::_init(const char* lbl, uint8_t x, uint8_t y,
                            uint8_t size, float aspect)
{
    _x        = x;
    _y        = y;
    _size     = size;
    _aspect   = floatToAspect(aspect);
    _rotation = 0;
    _visible  = true;

    if (lbl && lbl[0] != '\0') {
        strncpy(_label, lbl, RADIOKIT_MAX_LABEL);
        _label[RADIOKIT_MAX_LABEL] = '\0';
    } else {
        _label[0] = '\0';
    }

    _registerSelf();
}

void RadioKit_Widget::_registerSelf() {
    RadioKit._registerWidget(this);
}

void RadioKit_Widget::setPosition(uint8_t x, uint8_t y) {
    _x = x; _y = y;
}

void RadioKit_Widget::setPosition(uint8_t x, uint8_t y, int16_t rot) {
    _x = x; _y = y; _rotation = rot;
}

void RadioKit_Widget::setSize(uint8_t size) {
    _size = size;
}

void RadioKit_Widget::setSize(uint8_t size, float aspectRatio) {
    _size   = size;
    _aspect = floatToAspect(aspectRatio);
}

void RadioKit_Widget::setAspectRatio(float aspectRatio) {
    _aspect = floatToAspect(aspectRatio);
}

void RadioKit_Widget::show() { _visible = true;  }
void RadioKit_Widget::hide() { _visible = false; }
