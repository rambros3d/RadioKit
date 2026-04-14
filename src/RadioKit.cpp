/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization.
 */

#include "RadioKit.h"
#include <string.h>

RadioKitClass RadioKit;
static RadioKitClass* s_instance = nullptr;

RadioKitClass::RadioKitClass()
    : _widgetCount(0)
    , _orientation(RK_LANDSCAPE)
    , _transport(nullptr)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    s_instance = this;
}

// ─────────────────────────────────────────────
void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

// ─────────────────────────────────────────────
void RadioKitClass::startBLE(const char* deviceName, const char* /*password*/) {
    _transport = &RadioKitBLEInstance;
    _transport->begin(deviceName, RadioKitClass::_onPacket);
}

void RadioKitClass::startSerial(Stream& stream, uint32_t baud) {
    _transport = &RadioKitSerialInstance;
    RadioKitSerialInstance.begin(stream, baud, RadioKitClass::_onPacket);
}

// ─────────────────────────────────────────────
void RadioKitClass::update() {
    if (_transport) _transport->update();
}

bool RadioKitClass::isConnected() const {
    return _transport ? _transport->isConnected() : false;
}

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

void RadioKitClass::_handleGetConf() {
    uint8_t  buf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t len = _buildConfPayload(buf, sizeof(buf));
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, buf, len);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

void RadioKitClass::_handleGetVars() {
    uint8_t  buf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t len = _buildVarPayload(buf, sizeof(buf));
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, buf, len);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

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
    uint16_t pkt = rk_buildAck(_txBuf);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

void RadioKitClass::_handlePing() {
    uint16_t pkt = rk_buildPong(_txBuf);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

uint16_t RadioKitClass::_totalInputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) total += _widgets[i]->inputSize();
    return total;
}

uint16_t RadioKitClass::_totalOutputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) total += _widgets[i]->outputSize();
    return total;
}

// ─────────────────────────────────────────────
//  _buildConfPayload
//  [PROTO_VER][ORIENTATION][NUM_WIDGETS]
//  per widget: [TYPE][ID][X][Y][SIZE][ASPECT][ROTATION][LABEL_LEN][LABEL...]
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
        if (out + 8 + labelLen > bufSize) break;
        buf[out++] = wgt->typeId;
        buf[out++] = wgt->widgetId;
        buf[out++] = wgt->x();
        buf[out++] = wgt->y();
        buf[out++] = wgt->size();
        buf[out++] = wgt->aspect();   // uint8_t, ×10 scale, never 0
        buf[out++] = (uint8_t)RK_ROT(wgt->rotation());
        buf[out++] = labelLen;
        memcpy(&buf[out], wgt->label(), labelLen);
        out += labelLen;
    }
    return out;
}

// ─────────────────────────────────────────────
//  _buildVarPayload
//  [input vars echoed as 0x00...][output vars]
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        memset(&buf[out], 0, sz);
        out += sz;
    }
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
