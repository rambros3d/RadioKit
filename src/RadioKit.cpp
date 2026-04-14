/**
 * RadioKit.cpp
 * Core implementation — config parsing, struct sync, protocol dispatch.
 */

#include "RadioKit.h"
#include <string.h>

// ─────────────────────────────────────────────
//  Global singleton
// ─────────────────────────────────────────────
RadioKitClass RadioKit;

static RadioKitClass* s_instance = nullptr;

// ─────────────────────────────────────────────
//  Descriptor stride:
//  Each widget entry in _rk_conf[] after the 3-byte header is:
//    [TYPE][X][Y][W][H][ROTATION][LABEL_LEN][LABEL x 32]
//  = 7 fixed bytes + 32 label bytes = 39 bytes total per widget.
//  The label is always stored as 32 bytes (padded with original
//  string chars; unused bytes are garbage but LABEL_LEN tells
//  the receiver how many are valid).
// ─────────────────────────────────────────────
#define RK_DESC_FIXED   7    // TYPE + X + Y + W + H + ROTATION + LABEL_LEN
#define RK_LABEL_STORED 32   // label bytes always stored in PROGMEM
#define RK_DESC_STRIDE  (RK_DESC_FIXED + RK_LABEL_STORED)  // 39

// Byte offsets within a descriptor
#define RK_DESC_TYPE      0
#define RK_DESC_X         1
#define RK_DESC_Y         2
#define RK_DESC_W         3
#define RK_DESC_H         4
#define RK_DESC_ROTATION  5
#define RK_DESC_LABELSIZE 6
#define RK_DESC_LABEL     7

// Config array header offsets
#define RK_CONF_VERSION   0
#define RK_CONF_ORIENT    1
#define RK_CONF_NWIDGETS  2
#define RK_CONF_HEADER    3  // first widget descriptor starts here

// End sentinel in config array
#define RK_CONF_SENTINEL  0xFF

// ─────────────────────────────────────────────
//  Constructor
// ─────────────────────────────────────────────
RadioKitClass::RadioKitClass()
    : _structPtr(nullptr)
    , _inputBytes(0)
    , _outputBytes(0)
    , _connectFlagOffset(0)
    , _widgetCount(0)
    , _confReady(false)
{
    memset(_txBuf, 0, sizeof(_txBuf));
    s_instance = this;
}

// ─────────────────────────────────────────────
//  _widgetInputSize / _widgetOutputSize
// ─────────────────────────────────────────────
uint8_t RadioKitClass::_widgetInputSize(uint8_t typeId) {
    switch (typeId) {
        case RK_TYPE_BUTTON:   return 1;
        case RK_TYPE_SWITCH:   return 1;
        case RK_TYPE_SLIDER:   return 1;
        case RK_TYPE_JOYSTICK: return 2;  // X + Y
        case RK_TYPE_LED:      return 0;
        case RK_TYPE_TEXT:     return 0;
        default:               return 0;
    }
}

uint8_t RadioKitClass::_widgetOutputSize(uint8_t typeId) {
    switch (typeId) {
        case RK_TYPE_BUTTON:   return 0;
        case RK_TYPE_SWITCH:   return 0;
        case RK_TYPE_SLIDER:   return 0;
        case RK_TYPE_JOYSTICK: return 0;
        case RK_TYPE_LED:      return 1;
        case RK_TYPE_TEXT:     return RADIOKIT_TEXT_LEN;
        default:               return 0;
    }
}

// ─────────────────────────────────────────────
//  _parseConfig
//  Walks _rk_conf[] PROGMEM to resolve widget count,
//  input/output byte totals, and connect_flag offset.
// ─────────────────────────────────────────────
void RadioKitClass::_parseConfig() {
    _widgetCount       = 0;
    _inputBytes        = 0;
    _outputBytes       = 0;
    _connectFlagOffset = 0;
    _confReady         = false;

    // Verify header sentinel is present at NWIDGETS slot (0xFF = unfilled)
    // Walk from first descriptor offset until we hit the end sentinel 0xFF
    uint16_t pos = RK_CONF_HEADER;
    while (true) {
        uint8_t typeId = pgm_read_byte(&_rk_conf[pos]);
        if (typeId == RK_CONF_SENTINEL) break;  // end of descriptors
        if (_widgetCount >= RADIOKIT_MAX_WIDGETS) break;  // safety cap

        _inputBytes  += _widgetInputSize(typeId);
        _outputBytes += _widgetOutputSize(typeId);
        _widgetCount++;
        pos += RK_DESC_STRIDE;
    }

    // connect_flag sits immediately after all input + output bytes
    _connectFlagOffset = _inputBytes + _outputBytes;
    _confReady = true;
}

// ─────────────────────────────────────────────
//  begin
// ─────────────────────────────────────────────
void RadioKitClass::begin(const char* deviceName, void* structPtr) {
    _structPtr = structPtr;
    _parseConfig();
    RadioKitBLEInstance.begin(deviceName, RadioKitClass::_onPacket);
}

// ─────────────────────────────────────────────
//  handle
// ─────────────────────────────────────────────
void RadioKitClass::handle() {
    RadioKitBLEInstance.update();

    // Keep connect_flag in sync with BLE state
    if (_structPtr && _confReady) {
        uint8_t* base = (uint8_t*)_structPtr;
        base[_connectFlagOffset] = RadioKitBLEInstance.isConnected() ? 1 : 0;
    }
}

// ─────────────────────────────────────────────
//  isConnected
// ─────────────────────────────────────────────
bool RadioKitClass::isConnected() const {
    return RadioKitBLEInstance.isConnected();
}

// ─────────────────────────────────────────────
//  Static packet dispatcher
// ─────────────────────────────────────────────
void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;
    switch (cmd) {
        case RK_CMD_GET_CONF:  s_instance->_handleGetConf();                    break;
        case RK_CMD_GET_VARS:  s_instance->_handleGetVars();                    break;
        case RK_CMD_SET_INPUT: s_instance->_handleSetInput(payload, payloadLen); break;
        case RK_CMD_PING:      s_instance->_handlePing();                       break;
        default: break;
    }
}

// ─────────────────────────────────────────────
//  _handleGetConf  →  send CONF_DATA
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetConf() {
    uint8_t  payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildConfPayload(payloadBuf, sizeof(payloadBuf));
    uint16_t pktLen     = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleGetVars  →  send VAR_DATA
// ─────────────────────────────────────────────
void RadioKitClass::_handleGetVars() {
    uint8_t  payloadBuf[RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE];
    uint16_t payloadLen = _buildVarPayload(payloadBuf, sizeof(payloadBuf));
    uint16_t pktLen     = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, payloadBuf, payloadLen);
    RadioKitBLEInstance.sendPacket(_txBuf, pktLen);
}

// ─────────────────────────────────────────────
//  _handleSetInput  →  memcpy into struct, send ACK
// ─────────────────────────────────────────────
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    if (!_structPtr || !_confReady) return;
    if (len < _inputBytes) return;  // payload too short

    // Input bytes sit at offset 0 in the struct
    memcpy((uint8_t*)_structPtr, payload, _inputBytes);

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
//  Copies config directly from PROGMEM, patching the widget count byte.
//  Output format:
//    [PROTO_VERSION][ORIENTATION][NUM_WIDGETS][descriptor...]
//    Each descriptor: [TYPE][X][Y][W][H][ROTATION][LABEL_LEN][LABEL...]
//    LABEL is trimmed to LABEL_LEN bytes (no padding sent on wire).
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    // 3-byte header
    if (out + 3 > bufSize) return 0;
    buf[out++] = pgm_read_byte(&_rk_conf[RK_CONF_VERSION]);
    buf[out++] = pgm_read_byte(&_rk_conf[RK_CONF_ORIENT]);
    buf[out++] = _widgetCount;  // patch in the resolved count

    // Widget descriptors
    uint16_t pos = RK_CONF_HEADER;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        uint8_t typeId   = pgm_read_byte(&_rk_conf[pos + RK_DESC_TYPE]);
        uint8_t x        = pgm_read_byte(&_rk_conf[pos + RK_DESC_X]);
        uint8_t y        = pgm_read_byte(&_rk_conf[pos + RK_DESC_Y]);
        uint8_t w        = pgm_read_byte(&_rk_conf[pos + RK_DESC_W]);
        uint8_t h        = pgm_read_byte(&_rk_conf[pos + RK_DESC_H]);
        uint8_t rotation = pgm_read_byte(&_rk_conf[pos + RK_DESC_ROTATION]);
        uint8_t labelLen = pgm_read_byte(&_rk_conf[pos + RK_DESC_LABELSIZE]);

        // 7 fixed bytes + actual label bytes
        uint16_t needed = 7 + labelLen;
        if (out + needed > bufSize) break;  // safety

        buf[out++] = typeId;
        buf[out++] = i;         // widget ID = sequential index
        buf[out++] = x;
        buf[out++] = y;
        buf[out++] = w;
        buf[out++] = h;
        buf[out++] = rotation;
        buf[out++] = labelLen;

        for (uint8_t c = 0; c < labelLen && c < RK_LABEL_STORED; c++) {
            buf[out++] = pgm_read_byte(&_rk_conf[pos + RK_DESC_LABEL + c]);
        }

        pos += RK_DESC_STRIDE;
    }

    return out;
}

// ─────────────────────────────────────────────
//  _buildVarPayload
//  Direct memcpy of [inputs][outputs] from user struct.
// ─────────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    if (!_structPtr || !_confReady) return 0;

    uint16_t total = _inputBytes + _outputBytes;
    if (total > bufSize) return 0;

    memcpy(buf, (uint8_t*)_structPtr, total);
    return total;
}
