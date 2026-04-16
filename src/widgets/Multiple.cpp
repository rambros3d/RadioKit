#include "Multiple.h"
#include <string.h>

void RadioKit_Multiple::_initFromProps(const RK_MultipleProps& p, uint8_t tid) {
    props      = p;
    typeId     = tid;
    _poolCount = 0;
    memset(_pool, 0, sizeof(_pool));

    for (const RK_Item& item : p.items) {
        if (_poolCount >= RADIOKIT_MAX_ITEMS) break;
        uint8_t slot = _poolCount;
        if (item.pos < RADIOKIT_MAX_ITEMS) slot = item.pos;
        _pool[slot] = item;
        _poolCount++;
    }

    _init(p.label, p.x, p.y, p.scale, 0.0f, p.style, p.variant,
          p.icon, nullptr, nullptr, p.rotation);
}

void RadioKit_Multiple::deserializeInput(const uint8_t* buf) {
    props.value = buf[0];
}

void RadioKit_Multiple::serializeInput(uint8_t* buf) const {
    buf[0] = props.value;
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

RK_MultipleButton::RK_MultipleButton(RK_MultipleProps p) {
    _initFromProps(p, RK_TYPE_MULTIPLE);
}

RK_MultipleSelect::RK_MultipleSelect(RK_MultipleProps p) {
    _initFromProps(p, RK_TYPE_MULTIPLE);
}
uint8_t RadioKit_Multiple::serializeStrings(uint8_t* buf) const {
    uint8_t mask = 0;
    if (_label[0]   != '\0') mask |= RK_STR_LABEL;
    if (_icon[0]    != '\0') mask |= RK_STR_ICON;
    if (_onText[0]  != '\0') mask |= RK_STR_ONTEXT;
    if (_offText[0] != '\0') mask |= RK_STR_OFFTEXT;

    // Build pipe-delimited items string
    char itemsStr[128]; 
    itemsStr[0] = '\0';
    for (uint8_t i = 0; i < _poolCount; i++) {
        if (i > 0) strncat(itemsStr, "|", sizeof(itemsStr) - strlen(itemsStr) - 1);
        strncat(itemsStr, _pool[i].label, sizeof(itemsStr) - strlen(itemsStr) - 1);
    }
    if (itemsStr[0] != '\0') mask |= RK_STR_CONTENT;

    uint8_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s) {
        uint8_t len = (uint8_t)strnlen(s, RADIOKIT_MAX_LABEL * 4); // content can be longer
        buf[out++] = len;
        memcpy(&buf[out], s, len);
        out += len;
    };

    if (mask & RK_STR_LABEL)   _writeStr(_label);
    if (mask & RK_STR_ICON)    _writeStr(_icon);
    if (mask & RK_STR_ONTEXT)  _writeStr(_onText);
    if (mask & RK_STR_OFFTEXT) _writeStr(_offText);
    if (mask & RK_STR_CONTENT) _writeStr(itemsStr);

    return out;
}
