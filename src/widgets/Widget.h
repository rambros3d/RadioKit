/**
 * Widget.h
 * Abstract base class for all RadioKit widgets (v2.0).
 */

#ifndef RADIOKIT_WIDGET_H
#define RADIOKIT_WIDGET_H

#include <Arduino.h>
#include <stdint.h>
#include "../RadioKitConfig.h"

class RadioKit_Widget {
public:
    RadioKit_Widget();
    virtual ~RadioKit_Widget() {}

    // ── Identity ───────────────────────────────────────────────────────
    uint8_t typeId;
    uint8_t widgetId;

    // ── Accessors ──────────────────────────────────────────────────────
    uint8_t     x()        const { return _x; }
    uint8_t     y()        const { return _y; }
    /// Scale ×10 (e.g. 1.5 → 15)
    uint8_t     scale()    const { return _scale; }
    /// Aspect ×10 (e.g. 2.5 → 25). 0 = use widget default.
    uint8_t     aspect()   const { return _aspect != 0 ? _aspect : defaultAspect(); }
    /// Rotation in degrees (absolute).
    int16_t     rotation() const { return _rotation; }
    bool        enabled()  const { return _enabled; }
    uint8_t     style()    const { return _style; }
    uint8_t     variant()  const { return _variant; }
    const char* label()    const { return _label; }
    const char* icon()     const { return _icon; }
    const char* onText()   const { return _onText; }
    const char* offText()  const { return _offText; }

    // ── Serialization ─────────────────────────────────────────────────────
    virtual uint8_t inputSize()  const = 0;
    virtual uint8_t outputSize() const = 0;
    /// Writes the current input-side value(s) to [buf]. Called by GET_VARS.
    virtual void serializeInput(uint8_t* buf)          const = 0;
    /// Writes the current output-side value(s) to [buf]. Called by GET_VARS.
    virtual void serializeOutput(uint8_t* buf)         const = 0;
    virtual void deserializeInput(const uint8_t* buf)        = 0;

    virtual uint8_t serializeStrings(uint8_t* buf) const;

protected:
    uint8_t  _x, _y;
    uint8_t  _scale;
    uint8_t  _aspect;
    int16_t  _rotation;
    bool     _enabled;
    uint8_t  _style;
    uint8_t  _variant;
    char     _label  [RADIOKIT_MAX_LABEL + 1];
    char     _icon   [RADIOKIT_MAX_ICON  + 1];
    char     _onText [RADIOKIT_MAX_LABEL + 1];
    char     _offText[RADIOKIT_MAX_LABEL + 1];

    virtual uint8_t defaultAspect() const = 0;

    /// rotation defaults to 0. Positive = clockwise in degrees.
    void _init(const char* label,  uint8_t x,        uint8_t y,
               float scale,        float   aspect,
               uint8_t style,      uint8_t variant,
               const char* icon,   const char* onText, const char* offText,
               int16_t rotation = 0);

private:
    void _registerSelf();
};

// ── Static helper ────────────────────────────────────────────────────────
static inline uint8_t _floatToWire(float f) {
    if (f <= 0.0f) return 0;
    float v = f * 10.0f + 0.5f;
    return (v > 255.0f) ? 255 : (uint8_t)v;
}

#endif // RADIOKIT_WIDGET_H
