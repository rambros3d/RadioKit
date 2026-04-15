/**
 * Widget.h
 * Abstract base class for all RadioKit widgets (v2.0).
 *
 * Stores all common fields defined in the protocol widget descriptor:
 *   TYPE, ID, X, Y, SCALE, ASPECT, ROTATION, STYLE, VARIANT, STR_MASK
 * Plus icon / onText / offText strings used by string-bitmask serialization.
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

    // ── Identity ─────────────────────────────────────────────
    uint8_t typeId;    ///< RK_TYPE_* constant
    uint8_t widgetId;  ///< Assigned by RadioKitClass._registerWidget()

    // ── Accessors ────────────────────────────────────────────
    uint8_t     x()        const { return _x; }
    uint8_t     y()        const { return _y; }
    /// Scale ×10 (e.g. 1.5 → 15)
    uint8_t     scale()    const { return _scale; }
    /// Aspect ×10 (e.g. 2.5 → 25). 0 = use widget default.
    uint8_t     aspect()   const { return _aspect != 0 ? _aspect : defaultAspect(); }
    int16_t     rotation() const { return _rotation; }
    bool        enabled()  const { return _enabled; }
    uint8_t     style()    const { return _style; }
    uint8_t     variant()  const { return _variant; }
    const char* label()    const { return _label; }
    const char* icon()     const { return _icon; }
    const char* onText()   const { return _onText; }
    const char* offText()  const { return _offText; }

    // ── Serialization ────────────────────────────────────────
    virtual uint8_t inputSize()  const = 0;
    virtual uint8_t outputSize() const = 0;
    virtual void serializeOutput(uint8_t* buf)         const = 0;
    virtual void deserializeInput(const uint8_t* buf)        = 0;

    /** Writes the string-bitmask byte followed by [LEN][STR] pairs.
     *  Returns number of bytes written. buf must be large enough. */
    uint8_t serializeStrings(uint8_t* buf) const;

protected:
    uint8_t  _x, _y;
    uint8_t  _scale;    ///< ×10 scale: 10 = 1.0, 15 = 1.5
    uint8_t  _aspect;   ///< ×10 scale: 0=use default, 25=2.5
    int16_t  _rotation;
    bool     _enabled;
    uint8_t  _style;
    uint8_t  _variant;
    char     _label  [RADIOKIT_MAX_LABEL + 1];
    char     _icon   [RADIOKIT_MAX_ICON  + 1];
    char     _onText [RADIOKIT_MAX_LABEL + 1];
    char     _offText[RADIOKIT_MAX_LABEL + 1];

    virtual uint8_t defaultAspect() const = 0;

    void _init(const char* label,  uint8_t x,       uint8_t y,
               float scale,        float   aspect,
               uint8_t style,      uint8_t variant,
               const char* icon,   const char* onText, const char* offText);

private:
    void _registerSelf();
};

// ── Static helper ────────────────────────────────────────────
static inline uint8_t _floatToWire(float f) {
    if (f <= 0.0f) return 0;
    float v = f * 10.0f + 0.5f;
    return (v > 255.0f) ? 255 : (uint8_t)v;
}

#endif // RADIOKIT_WIDGET_H
