/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization (v2.0 / Protocol v3).
 */

#include "RadioKit.h"
#include <string.h>

RadioKitClass RadioKit;
static RadioKitClass* s_instance = nullptr;

// Forward-declared in Widget.cpp
extern void RadioKit_Widget_drainDeferred();

RadioKitClass::RadioKitClass()
    : _widgetCount(0)
    , _transport(nullptr)
    , _pendingUpdatesMask(0)
    , _varUpdateSeq(0)
    , _varUpdateId(0)
    , _varUpdateRetries(0)
    , _varUpdateSentAt(0)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    memset(_shadowInput, 0, sizeof(_shadowInput));
    s_instance = this;
}

void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

void RadioKitClass::begin() {
    RadioKit_Widget_drainDeferred();
}

void RadioKitClass::pushUpdate(uint8_t widgetId) {
    if (widgetId < _widgetCount && widgetId < 32) {
        _pendingUpdatesMask |= (1UL << widgetId);
    }
}

void RadioKitClass::startBLE(const char* deviceName) {
    const char* name = (deviceName && deviceName[0] != '\0') ? deviceName : config.name;
    _transport = &RadioKitBLEInstance;
    _transport->begin(name, RadioKitClass::_onPacket);
}

void RadioKitClass::startSerial(Stream& stream) {
    _transport = &RadioKitSerialInstance;
    RadioKitSerialInstance.begin(stream, RadioKitClass::_onPacket);
}

void RadioKitClass::update() {
    if (_transport) _transport->update();

    if (_transport && _transport->isConnected()) {
        for (uint8_t i = 0; i < _widgetCount; i++) {
            RadioKit_Widget* w = _widgets[i];
            uint8_t inSz = w->inputSize();
            if (inSz > 0 && inSz <= 4) {
                uint8_t currentBuf[4] = {0};
                w->serializeInput(currentBuf);
                if (memcmp(currentBuf, _shadowInput[i], inSz) != 0) {
                    memcpy(_shadowInput[i], currentBuf, inSz);
                    pushUpdate(i); // enqueue an update
                }
            }
        }
    }

    if (_pendingUpdatesMask != 0 && _transport && _transport->isConnected()) {
        if ((_pendingUpdatesMask & (1UL << _varUpdateId)) == 0) {
            // Current ID was ACKed or dropped. Pick next.
            for (uint8_t i = 0; i < 32; i++) {
                if (_pendingUpdatesMask & (1UL << i)) {
                    _varUpdateId = i;
                    _varUpdateSeq++;
                    _varUpdateRetries = 0;
                    _varUpdateSentAt = 0;
                    break;
                }
            }
        }
        
        uint32_t now = millis();
        // Force send on first run (_varUpdateSentAt == 0) or if timeout exceeded
        if (_varUpdateSentAt == 0 || now - _varUpdateSentAt >= RK_VAR_UPDATE_TIMEOUT_MS) {
            if (_varUpdateRetries >= RK_VAR_UPDATE_MAX_RETRIES) {
                // Drop and move on.
                _pendingUpdatesMask &= ~(1UL << _varUpdateId);
                _varUpdateRetries = 0;
            } else {
                RadioKit_Widget* w = _widgets[_varUpdateId];
                uint8_t inSz = w->inputSize();
                uint8_t outSz = w->outputSize();
                uint8_t dataSz = inSz > 0 ? inSz : outSz;
                uint8_t payload[2 + dataSz];
                payload[0] = _varUpdateId;
                payload[1] = _varUpdateSeq;
                uint8_t cmd = RK_CMD_VAR_UPDATE;
                if (inSz > 0) {
                    w->serializeInput(&payload[2]);
                    cmd = RK_CMD_SET_INPUT;
                } else {
                    w->serializeOutput(&payload[2]);
                }
                uint16_t pkt = rk_buildPacket(_txBuf, cmd, payload, 2 + dataSz);
                _transport->sendPacket(_txBuf, pkt);
                _varUpdateSentAt = now;
                _varUpdateRetries++;
            }
        }
    }
}

bool RadioKitClass::isConnected() const {
    return _transport ? _transport->isConnected() : false;
}

void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;
    switch (cmd) {
        case RK_CMD_GET_CONF:  s_instance->_handleGetConf();                      break;
        case RK_CMD_GET_VARS:  s_instance->_handleGetVars();                      break;
        case RK_CMD_SET_INPUT: s_instance->_handleSetInput(payload, payloadLen);  break;
        case RK_CMD_PING:      s_instance->_handlePing();                         break;
        case RK_CMD_ACK:       s_instance->_handleAck(payload, payloadLen);       break;
        case RK_CMD_VAR_UPDATE:s_instance->_handleVarUpdate(payload, payloadLen); break;
        default: break;
    }
}

void RadioKitClass::_handleGetConf() {
    uint16_t payloadLen = _buildConfPayload(&_txBuf[RK_HEADER_SIZE],
                                            RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, nullptr, payloadLen);
    if (_transport) _transport->sendPacket(_txBuf, totalLen);
}

void RadioKitClass::_handleGetVars() {
    uint16_t payloadLen = _buildVarPayload(&_txBuf[RK_HEADER_SIZE],
                                           RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, nullptr, payloadLen);
    if (_transport) _transport->sendPacket(_txBuf, totalLen);
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
    uint8_t seq = 0;
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &seq, 1);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

void RadioKitClass::_handlePing() {
    uint16_t pkt = rk_buildPong(_txBuf);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

void RadioKitClass::_handleAck(const uint8_t* payload, uint16_t len) {
    if (_pendingUpdatesMask == 0) return;
    if (len >= 1 && payload[0] == _varUpdateSeq) {
        _pendingUpdatesMask &= ~(1UL << _varUpdateId);
        _varUpdateRetries = 0;
    }
}

void RadioKitClass::_handleVarUpdate(const uint8_t* payload, uint16_t len) {
    if (len < 2) return;
    uint8_t widgetId = payload[0];
    uint8_t seq = payload[1];
    if (widgetId >= _widgetCount) return;

    RadioKit_Widget* w = _widgets[widgetId];
    uint8_t sz = w->inputSize();
    if (sz > 0 && 2 + sz <= len) {
        w->deserializeInput(&payload[2]);
        if (sz <= 4) {
            memcpy(_shadowInput[widgetId], &payload[2], sz);
        }
    }
    
    // Ack back to sender
    uint16_t pkt = rk_buildAck(_txBuf, seq);
    if (_transport) _transport->sendPacket(_txBuf, pkt);
}

// ── CONF_DATA payload builder (Protocol v3) ──────────────────────────────
//
// strBuf worst-case per widget:
//   mask(1)
//   + label:   len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + icon:    len(1) + RADIOKIT_MAX_ICON(24)     = 25
//   + onText:  len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + offText: len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + content: len(1) + RADIOKIT_MAX_ITEMS*(RADIOKIT_MAX_LABEL+RADIOKIT_MAX_ICON+2) pipes
//            = 1 + 8*(32+24+2) = 1 + 464 = 465  (Multiple widget worst case)
// Total worst case = 1+33+25+33+33+465 = 590 bytes → use 640 to be safe.
#define RK_STR_BUF_SIZE 640

uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    const char* name = config.name ? config.name : "";
    const char* pwd  = config.password ? config.password : "";
    const char* themeStr = config.theme ? config.theme : RK_DEFAULT;
    uint8_t nameLen  = (uint8_t)strnlen(name, RADIOKIT_MAX_LABEL);
    uint8_t pwdLen   = (uint8_t)strnlen(pwd,  RADIOKIT_MAX_LABEL);
    uint8_t themeLen = (uint8_t)strnlen(themeStr, 64);

    if (out + 6 + nameLen + pwdLen + themeLen > bufSize) return 0;

    buf[out++] = RK_PROTOCOL_VERSION;
    buf[out++] = config.orientation;
    buf[out++] = _widgetCount;
    buf[out++] = nameLen;
    memcpy(&buf[out], name, nameLen); out += nameLen;
    buf[out++] = pwdLen;
    memcpy(&buf[out], pwd, pwdLen);   out += pwdLen;
    buf[out++] = themeLen;
    memcpy(&buf[out], themeStr, themeLen); out += themeLen;

    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];

        if (out + 10 > bufSize) break;
        buf[out++] = w->typeId;
        buf[out++] = w->widgetId;
        buf[out++] = w->x();
        buf[out++] = w->y();
        buf[out++] = w->scale();
        buf[out++] = w->aspect();
        int16_t rot = w->rotation();
        buf[out++] = (uint8_t)(rot & 0xFF);
        buf[out++] = (uint8_t)((rot >> 8) & 0xFF);
        buf[out++] = w->style();
        buf[out++] = w->variant();

        // Write strings directly to the target buffer.
        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break; // No more room for this widget's strings
        }
    }
    return out;
}

// ── VAR_DATA payload builder ──────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
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
