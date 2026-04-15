#include "Multiple.h"
#include <string.h>

void RadioKit_Multiple::_initFromProps(const RK_MultipleProps& p, uint8_t tid) {
    props     = p;
    typeId    = tid;
    _poolCount = 0;
    memset(_pool, 0, sizeof(_pool));

    // Load initial items from initializer_list into pool
    for (const RK_Item& item : p.items) {
        if (_poolCount >= RADIOKIT_MAX_ITEMS) break;
        uint8_t slot = (_poolCount < RADIOKIT_MAX_ITEMS) ? _poolCount : 0;
        // If pos is fixed, place at that slot
        if (item.pos < RADIOKIT_MAX_ITEMS) {
            slot = item.pos;
        }
        _pool[slot] = item;
        _poolCount++;
    }

    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, p.variant,
          p.icon, nullptr, nullptr);
}

void RadioKit_Multiple::deserializeInput(const uint8_t* buf) {
    props.value = buf[0];
}

void RadioKit_Multiple::clear() {
    memset(_pool, 0, sizeof(_pool));
    _poolCount  = 0;
    props.value = 0;
}

void RadioKit_Multiple::add(const RK_Item& item) {
    if (_poolCount >= RADIOKIT_MAX_ITEMS) return;
    uint8_t slot = _poolCount;
    if (item.pos < RADIOKIT_MAX_ITEMS) slot = item.pos;
    _pool[slot] = item;
    _poolCount++;
}

void RadioKit_Multiple::remove(uint8_t index) {
    if (index >= RADIOKIT_MAX_ITEMS) return;
    memset(&_pool[index], 0, sizeof(RK_Item));
    if (_poolCount > 0) _poolCount--;
}

void RadioKit_Multiple::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
}

// ── MultipleButton ───────────────────────────────────────────
RK_MultipleButton::RK_MultipleButton(RK_MultipleProps p) {
    _initFromProps(p, RK_TYPE_MULTIPLE);
}

// ── MultipleSelect ───────────────────────────────────────────
RK_MultipleSelect::RK_MultipleSelect(RK_MultipleProps p) {
    _initFromProps(p, RK_TYPE_MULTIPLE);
}
