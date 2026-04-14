/**
 * Widget.h
 * Abstract base class for all RadioKit widgets.
 *
 * Layout model:
 *   height = _size
 *   width  = _size * _aspect  (uses defaultAspect() if _aspect == 0)
 *
 * Both values are clamped to uint8_t (0-255) before wire serialization.
 */

#ifndef RADIOKIT_WIDGET_H
#define RADIOKIT_WIDGET_H

#include <Arduino.h>
#include <stdint.h>
#include "../RadioKitConfig.h"

class RadioKit_Widget {
public:
    // ── Construction ───────────────────────────────────────────
    RadioKit_Widget();
    virtual ~RadioKit_Widget() {}

    // ── Identity (set by subclass constructor) ─────────────────────
    uint8_t typeId;    ///< RK_TYPE_* constant
    uint8_t widgetId;  ///< Assigned by RadioKitClass at startBLE() time

    // ── Layout mutators ───────────────────────────────────────
    void setPosition(uint8_t x, uint8_t y);
    void setPosition(uint8_t x, uint8_t y, int16_t rotation);
    void setSize(uint8_t size);
    void setSize(uint8_t size, float aspectRatio);
    void setAspectRatio(float aspectRatio);
    void show();
    void hide();

    // ── Layout accessors ──────────────────────────────────────
    uint8_t x()        const { return _x; }
    uint8_t y()        const { return _y; }
    uint8_t size()     const { return _size; }
    float   aspect()   const { return _aspect > 0.0f ? _aspect : defaultAspect(); }
    int16_t rotation() const { return _rotation; }
    bool    visible()  const { return _visible; }
    const char* label() const { return _label; }

    /// Computed wire width:  size * resolved_aspect, clamped to uint8_t
    uint8_t w() const {
        float a = _aspect > 0.0f ? _aspect : defaultAspect();
        uint16_t val = (uint16_t)(_size * a + 0.5f);
        return val > 255 ? 255 : (uint8_t)val;
    }
    /// Computed wire height: size, clamped to uint8_t (it already is)
    uint8_t h() const { return _size; }

    // ── Serialization (override per widget type) ──────────────────
    virtual uint8_t inputSize()  const = 0;  ///< Bytes this widget contributes to SET_INPUT
    virtual uint8_t outputSize() const = 0;  ///< Bytes this widget contributes to VAR_DATA
    virtual void serializeOutput(uint8_t* buf)        const = 0;
    virtual void deserializeInput(const uint8_t* buf)       = 0;

protected:
    uint8_t  _x, _y;
    uint8_t  _size;
    float    _aspect;     ///< 0 = use defaultAspect()
    int16_t  _rotation;   ///< User degrees, -180..+180
    bool     _visible;
    char     _label[RADIOKIT_MAX_LABEL + 1];

    /// Subclasses must return their ideal aspect ratio when _aspect == 0
    virtual float defaultAspect() const = 0;

    /// Called by every subclass constructor to set label + register
    void _init(const char* label, uint8_t x, uint8_t y,
               uint8_t size, float aspect);

private:
    void _registerSelf();
};

#endif // RADIOKIT_WIDGET_H
