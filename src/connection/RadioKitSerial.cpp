/**
 * RadioKitSerial.cpp
 * USB Serial transport implementation.
 */

#include "RadioKitSerial.h"
#include "../RadioKitProtocol.h"

RadioKitSerialTransport RadioKitSerialInstance;

RadioKitSerialTransport::RadioKitSerialTransport()
    : _stream(nullptr), _cb(nullptr)
    , _lastPacketMs(0), _everReceived(false)
{}

void RadioKitSerialTransport::begin(Stream& stream, uint32_t /*baud*/,
                                    RK_PacketCallback cb)
{
    _stream       = &stream;
    _cb           = cb;
    _lastPacketMs = 0;
    _lastByteMs   = 0;
    _everReceived = false;

    rk_rxReset();
}

// Stub: satisfies the pure virtual when startBLE()-style call is made
void RadioKitSerialTransport::begin(const char* /*name*/, RK_PacketCallback cb) {
    // Should not be reached in normal usage; requires begin(stream, baud, cb).
    _cb = cb;
}

void RadioKitSerialTransport::update() {
    if (!_stream) return;

    uint8_t        cmd;
    const uint8_t* payload;
    uint16_t       payloadLen;

    while (_stream->available() > 0) {
        uint8_t byte = (uint8_t)_stream->read();
        _lastByteMs = millis();
        if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
            _lastPacketMs = millis();
            _everReceived = true;
            if (_cb) _cb(cmd, payload, payloadLen);
        }
    }

    // Recover from junk: if we are mid-packet but haven't seen an incoming byte
    // for 100ms, assume it was noise and reset the framing state.
    if ((millis() - _lastByteMs) > 100) {
        rk_rxReset();
    }
}

void RadioKitSerialTransport::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_stream) return;
    _stream->write(buf, len);
}

bool RadioKitSerialTransport::isConnected() const {
    if (!_everReceived) return false;
    return (millis() - _lastPacketMs) < TIMEOUT_MS;
}
