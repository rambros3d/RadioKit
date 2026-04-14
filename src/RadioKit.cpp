/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization.
 */

#include "RadioKit.h"
#include <string.h>

// ─────────────────────────────────────────────
RadioKitClass RadioKit;
static RadioKitClass* s_instance = nullptr;

RadioKitClass::RadioKitClass()
    : _widgetCount(0)
    , _orientation(RK_LANDSCAPE)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    s_instance = this;
}

// ─────────────────────────────────────────────
//  Widget self-registration
// ─────────────────────────────────────────────
void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

// ─────────────────────────────────────────────
//  startBLE
// ─────────────────────────────────────────────
void RadioKitClass::startBLE(const char* deviceName, const char* /*password*/) {
    RadioKitBLEInstance.begin(deviceName, RadioKitClass::_onPacket);
}

// ─────────────────────────────────────────────
//  update
// ─────────────────────────────────────────────
void RadioKitClass::update() {
    RadioKitBLEInstance.update();
}

// ─────────────────────────────────────────────
//  isConnected
// ─────────────────────────────────────────────
bool RadioKitClass::isConnected() const {
    return RadioKitBLEInstance.isConnected();
}

// ─────────────────────────────────────────────
//  Packet dispatcher
// ─────────────────────────────────────────────
void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;
    switch (cmd) {
        case RK_CMD_GET_CONF:  s_instance->_handleGetConf();                     break;
        case RK_CMD_GET_VARS:  s_instance->_handleGetVars();                     break;
        case RK_CMD_SET_INPUT: s_instance->_handleSetInput(payload, payloadLen); break;
        case RK_CMD_PING:      s_instance->_handlePing();                        break;
        default: break;
    }
}

// ─────────────────────────────────────────────
//  _handleGetConf
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetConf() {
    uint8_t  payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildConfPayload(payloadBuf, sizeof(payloadBuf));
    uint16_t pktLen     = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleGetVars
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetVars() {
    uint8_t  payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildVarPayload(payloadBuf, sizeof(payloadBuf));
    uint16_t pktLen     = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleSetInput
// ─────────────────────────────────────────────
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    uint16_t offset = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (sz == 0) continue;
        if (offset + sz > len) break;
        w->deserializeInput(payload + offset);
        offset += sz;
    }
    uint16_t pktLen = rk_buildAck(_txBuf);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handlePing
// ─────────────────────────────────────────────
void RadioKitClass::_handlePing() {
    uint16_t pktLen = rk_buildPong(_txBuf);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _totalInputBytes / _totalOutputBytes
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_totalInputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++)
        total += _widgets[i]->inputSize();
    return total;
}

uint16_t RadioKitClass::_totalOutputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++)
        total += _widgets[i]->outputSize();
    return total;
}

// ─────────────────────────────────────────────
//  _buildConfPayload
//  Format: [PROTO_VER][ORIENTATION][NUM_WIDGETS]
//          then per widget: [TYPE][ID][X][Y][W][H][ROTATION][LABEL_LEN][LABEL...]
//  W and H are computed from size * aspect at call time.
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    if (out + 3 > bufSize) return 0;
    buf[out++] = RK_PROTOCOL_VERSION;
    buf[out++] = (uint8_t)_orientation;
    buf[out++] = _widgetCount;

    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* wgt = _widgets[i];
        uint8_t labelLen = (uint8_t)strnlen(wgt->label(), RADIOKIT_MAX_LABEL);
        uint16_t needed  = 8 + labelLen;  // TYPE+ID+X+Y+W+H+ROT+LABEL_LEN + label
        if (out + needed > bufSize) break;

        buf[out++] = wgt->typeId;
        buf[out++] = wgt->widgetId;
        buf[out++] = wgt->x();
        buf[out++] = wgt->y();
        buf[out++] = wgt->w();          // computed: size * resolvedAspect
        buf[out++] = wgt->h();          // = size
        buf[out++] = (uint8_t)RK_ROT(wgt->rotation());
        buf[out++] = labelLen;
        memcpy(&buf[out], wgt->label(), labelLen);
        out += labelLen;
    }

    return out;
}

// ─────────────────────────────────────────────
//  _buildVarPayload
//  [input vars in widget order] [output vars in widget order]
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    // Input vars first
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        // Input widgets have no serializeInput; their state is already
        // deserialized into the widget. For VAR_DATA we echo it back.
        // Re-serialize by writing the raw state bytes.
        w->serializeOutput(&buf[out]);  // fallback: output widgets use this
        // For input-only widgets, write zeros (app doesn't use input echo)
        memset(&buf[out], 0, sz);
        out += sz;
    }

    // Output vars
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->outputSize();
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        w->serializeOutput(&buf[out]);
        out += sz;
    }

    return out;
}
