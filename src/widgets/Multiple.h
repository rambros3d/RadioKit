/**
 * Multiple.h
 * RK_MultipleButton — radio-group (single select)
 * RK_MultipleSelect  — checkbox-group (multi select)
 *
 * State is an 8-bit bitmask. Item pool = 8 slots (RADIOKIT_MAX_ITEMS).
 */

#ifndef RADIOKIT_WIDGET_MULTIPLE_H
#define RADIOKIT_WIDGET_MULTIPLE_H

#include "Widget.h"
#include <initializer_list>

// ── Item ─────────────────────────────────────────────────────
struct RK_Item {
    const char* label = nullptr;
    const char* icon  = nullptr;
    uint32_t    color = 0;
    uint8_t     pos   = 255; ///< Fixed bitmask position (0-7). 255 = auto.
};

// ── Props struct ─────────────────────────────────────────────
struct RK_MultipleProps {
    const char* label   = nullptr;
    const char* icon    = nullptr;
    uint8_t     x       = 0;
    uint8_t     y       = 0;
    float       scale   = 1.0f;
    uint8_t     style   = 0;
    uint8_t     variant = 0;
    uint8_t     value   = 0; ///< Initial bitmask state
    std::initializer_list<RK_Item> items = {};
};

// ── Shared base ──────────────────────────────────────────────
class RadioKit_Multiple : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 30; // 3.0

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    /** Returns current bitmask. */
    uint8_t get()          const { return props.value; }
    /** Returns true if bit at index is set. */
    bool    get(uint8_t i) const { return (props.value & (1 << i)) != 0; }
    /** Clears all items and resets bitmask. */
    void    clear();
    /** Adds an item to the pool (max 8). */
    void    add(const RK_Item& item);
    /** Removes item at pool index. */
    void    remove(uint8_t index);
    /** Updates icon of the group heading. */
    void    setIcon(const char* val);

    RK_MultipleProps props;

protected:
    uint8_t defaultAspect() const override { return DEFAULT_ASPECT; }

    // Fixed 8-slot memory pool
    RK_Item  _pool[RADIOKIT_MAX_ITEMS];
    uint8_t  _poolCount = 0;

    void _initFromProps(const RK_MultipleProps& p, uint8_t tid);
};

// ── MultipleButton (radio) ───────────────────────────────────
class RK_MultipleButton : public RadioKit_Multiple {
public:
    RK_MultipleButton(RK_MultipleProps p);
};

// ── MultipleSelect (checkbox) ────────────────────────────────
class RK_MultipleSelect : public RadioKit_Multiple {
public:
    RK_MultipleSelect(RK_MultipleProps p);
};

#endif // RADIOKIT_WIDGET_MULTIPLE_H
