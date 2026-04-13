/**
 * RadioKit.cpp
 * Core implementation — widget registry, protocol dispatch, serialization.
 */

#include "RadioKit.h"
#include <string.h>

// ─────────────────────────────────────────────
//  Global singleton
// ─────────────────────────────────────────────
RadioKitClass RadioKit;

// Static pointer for the packet callback (bridges static function → instance)
static RadioKitClass* s_instance = nullptr;

// ─────────────────────────────────────────────
//  Constructor
// ─────────────────────────────────────────────
RadioKitClass::RadioKitClass()
    : _widgetCount(0)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf, 0, sizeof(_txBuf));
    s_instance = this;
}

// ─────────────────────────────────────────────
//  addWidget
// ─────────────────────────────────────────────
void RadioKitClass::addWidget(RadioKit_Widget& widget,
                              const char* label,
                              uint16_t x, uint16_t y,
                              uint16_t w, uint16_t h)
{
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) {
        // Silently ignore if table is full
        return;
    }

    // Assign sequential widget ID
    widget.widgetId = _widgetCount;
    widget.x = x;
    widget.y = y;
    widget.w = w;
    widget.h = h;

    // Copy label (truncate to RADIOKIT_MAX_LABEL)
    if (label) {
        strncpy(widget.label, label, RADIOKIT_MAX_LABEL);
        widget.label[RADIOKIT_MAX_LABEL] = '\0';
    } else {
        widget.label[0] = '\0';
    }

    _widgets[_widgetCount] = &widget;
    _widgetCount++;
}

// ─────────────────────────────────────────────
//  begin
// ─────────────────────────────────────────────
void RadioKitClass::begin(const char* deviceName) {
    RadioKitBLEInstance.begin(deviceName, RadioKitClass::_onPacket);
}

// ─────────────────────────────────────────────
//  handle
// ─────────────────────────────────────────────
void RadioKitClass::handle() {
    RadioKitBLEInstance.update();
}

// ─────────────────────────────────────────────
//  isConnected
// ─────────────────────────────────────────────
bool RadioKitClass::isConnected() const {
    return RadioKitBLEInstance.isConnected();
}

// ─────────────────────────────────────────────
//  Static packet callback (bridges to instance method)
// ─────────────────────────────────────────────
void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;

    switch (cmd) {
        case RK_CMD_GET_CONF:
            s_instance->_handleGetConf();
            break;
        case RK_CMD_GET_VARS:
            s_instance->_handleGetVars();
            break;
        case RK_CMD_SET_INPUT:
            s_instance->_handleSetInput(payload, payloadLen);
            break;
        case RK_CMD_PING:
            s_instance->_handlePing();
            break;
        default:
            // Unknown command — ignore
            break;
    }
}

// ─────────────────────────────────────────────
//  _handleGetConf  →  send CONF_DATA
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetConf() {
    // Build payload into a local buffer then wrap in packet
    uint8_t payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildConfPayload(payloadBuf, sizeof(payloadBuf));

    uint16_t pktLen = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA,
                                     payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleGetVars  →  send VAR_DATA
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetVars() {
    uint8_t payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildVarPayload(payloadBuf, sizeof(payloadBuf));

    uint16_t pktLen = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA,
                                     payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleSetInput  →  update widget values, send ACK
// ─────────────────────────────────────────────
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    uint16_t expected = _totalInputBytes();
    if (len < expected) {
        // Payload too short — discard
        return;
    }

    // Unpack input bytes in widget-registration order
    uint16_t offset = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t iSize = w->inputSize();
        if (iSize == 0) continue;

        if (offset + iSize > len) break; // safety guard
        w->deserializeInput(&payload[offset]);
        offset += iSize;
    }

    // Acknowledge
    uint16_t pktLen = rk_buildAck(_txBuf);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handlePing  →  send PONG
// ─────────────────────────────────────────────
void RadioKitClass::_handlePing() {
    uint16_t pktLen = rk_buildPong(_txBuf);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _buildConfPayload
//  Format: [PROTO_VERSION][NUM_WIDGETS][widget descriptors...]
//  Each widget: [TYPE_ID][WIDGET_ID][X_LO][X_HI][Y_LO][Y_HI]
//               [W_LO][W_HI][H_LO][H_HI][LABEL_LEN][LABEL...]
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t offset = 0;

    if (offset + 2 > bufSize) return 0;
    buf[offset++] = RK_PROTOCOL_VERSION;
    buf[offset++] = _widgetCount;

    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t labelLen   = (uint8_t)strlen(w->label);

        // Each widget descriptor = 11 + labelLen bytes
        uint16_t descriptorSize = 11 + labelLen;
        if (offset + descriptorSize > bufSize) break; // safety guard

        buf[offset++] = w->typeId;
        buf[offset++] = w->widgetId;

        // X (little-endian)
        buf[offset++] = (uint8_t)(w->x & 0xFF);
        buf[offset++] = (uint8_t)(w->x >> 8);

        // Y (little-endian)
        buf[offset++] = (uint8_t)(w->y & 0xFF);
        buf[offset++] = (uint8_t)(w->y >> 8);

        // W (little-endian)
        buf[offset++] = (uint8_t)(w->w & 0xFF);
        buf[offset++] = (uint8_t)(w->w >> 8);

        // H (little-endian)
        buf[offset++] = (uint8_t)(w->h & 0xFF);
        buf[offset++] = (uint8_t)(w->h >> 8);

        // Label
        buf[offset++] = labelLen;
        if (labelLen > 0) {
            memcpy(&buf[offset], w->label, labelLen);
            offset += labelLen;
        }
    }

    return offset;
}

// ─────────────────────────────────────────────
//  _buildVarPayload
//  Format: [input vars in widget order][output vars in widget order]
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t offset = 0;

    // Input variables first
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t iSize = w->inputSize();
        if (iSize == 0) continue;
        if (offset + iSize > bufSize) break;
        w->serializeInput(&buf[offset]);
        offset += iSize;
    }

    // Output variables after
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t oSize = w->outputSize();
        if (oSize == 0) continue;
        if (offset + oSize > bufSize) break;
        w->serializeOutput(&buf[offset]);
        offset += oSize;
    }

    return offset;
}

// ─────────────────────────────────────────────
//  _totalInputBytes / _totalOutputBytes
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_totalInputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        total += _widgets[i]->inputSize();
    }
    return total;
}

uint16_t RadioKitClass::_totalOutputBytes() const {
    uint16_t total = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        total += _widgets[i]->outputSize();
    }
    return total;
}
