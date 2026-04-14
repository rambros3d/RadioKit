/**
 * Widget.h
 * Abstract base class for all RadioKit widgets.
 *
 * Layout model (app-side):
 *   height = size
 *   width  = size * (aspect / 10.0)
 *
 * aspect is transmitted as uint8_t with ×10 scale:
 *   stored 0  = use widget's built-in default
 *   stored 10 = 1.0,  stored 25 = 2.5,  stored 255 = 25.5
 *
 * The Arduino side never multiplies size × aspect.
 * Both SIZE and ASPECT are sent on the wire; the app does the geometry.
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

    // ── Identity ────────────────────────────────────────────
    uint8_t typeId;    ///< RK_TYPE_* constant
    uint8_t widgetId;  ///< Assigned by RadioKitClass._registerWidget()

    // ── Layout mutators ──────────────────────────────────────
    void setPosition(uint8_t x, uint8_t y);
    void setPosition(uint8_t x, uint8_t y, int16_t rotation);
    void setSize(uint8_t size);
    void setSize(uint8_t size, float aspectRatio);
    void setAspectRatio(float aspectRatio);  ///< 0 reverts to widget default
    void show();
    void hide();

    // ── Layout accessors ──────────────────────────────────────
    uint8_t     x()        const { return _x; }
    uint8_t     y()        const { return _y; }
    uint8_t     size()     const { return _size; }
    /// Wire aspect value (uint8_t, ×10 scale). 0 = use widget default.
    /// Returns defaultAspect() if _aspect == 0.
    uint8_t     aspect()   const { return _aspect != 0 ? _aspect : defaultAspect(); }
    int16_t     rotation() const { return _rotation; }
    bool        visible()  const { return _visible; }
    const char* label()    const { return _label; }

    // ── Serialization ──────────────────────────────────────────
    virtual uint8_t inputSize()  const = 0;
    virtual uint8_t outputSize() const = 0;
    virtual void serializeOutput(uint8_t* buf)         const = 0;
    virtual void deserializeInput(const uint8_t* buf)        = 0;

protected:
    uint8_t  _x, _y;
    uint8_t  _size;
    uint8_t  _aspect;   ///< ×10 scale: 0=use default, 10=1.0, 25=2.5, 255=25.5
    int16_t  _rotation; ///< degrees, −180..+180
    bool     _visible;
    char     _label[RADIOKIT_MAX_LABEL + 1];

    /// Built-in default aspect ratio for this widget type, ×10 scale.
    /// e.g. 2.5 aspect → return 25
    virtual uint8_t defaultAspect() const = 0;

    void _init(const char* label, uint8_t x, uint8_t y,
               uint8_t size, float aspect);

private:
    void _registerSelf();
};

#endif // RADIOKIT_WIDGET_H
