/**
 * RadioKitSerial.cpp
 * USB Serial transport implementation.
 */

#include "RadioKitSerial.h"
#include "../RadioKitProtocol.h"

RadioKitSerialTransport RadioKitSerialInstance;

RadioKitSerialTransport::RadioKitSerialTransport()
    : _stream(nullptr), _cb(nullptr)
    , _lastPacketMs(0), _lastByteMs(0), _everReceived(false)
{}

void RadioKitSerialTransport::begin(Stream& stream, RK_PacketCallback cb) {
    _stream       = &stream;
    _cb           = cb;
    _lastPacketMs = 0;
    _lastByteMs   = 0;
    _everReceived = false;
    rk_rxReset();

    // Diagnostic LED (Lolin S3 Mini)
    pinMode(7, OUTPUT);
    digitalWrite(7, LOW);
}

void RadioKitSerialTransport::begin(const char* /*name*/, RK_PacketCallback cb) {
    _cb = cb;  // stream must be set via begin(Stream&, cb) overload
}

void RadioKitSerialTransport::update() {
    if (!_stream) return;

    uint8_t        cmd;
    const uint8_t* payload;
    uint16_t       payloadLen;

    while (_stream->available() > 0) {
        uint8_t byte = (uint8_t)_stream->read();
        _lastByteMs = millis();

        // Flicker LED on byte reception
        digitalWrite(7, HIGH);

        if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            
            // Toggle LED on valid packet
            static bool toggle = false;
            toggle = !toggle;
            digitalWrite(7, toggle ? HIGH : LOW);

            if (_cb) _cb(cmd, payload, payloadLen);
        } else {
            digitalWrite(7, LOW);
        }
    }

    // Junk recovery: reset framing if mid-packet but silent for >1000 ms
    if (_lastByteMs > 0 && (millis() - _lastByteMs) > 1000) {
        rk_rxReset();
        _lastByteMs = 0;
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
