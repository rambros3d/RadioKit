/**
 * RadioKitSerial.h
 * USB Serial transport for RadioKit.
 * Implements RadioKitTransport over any Arduino Stream (Serial, Serial1, …).
 *
 * Connection model:
 *   isConnected() returns true for TIMEOUT_MS after the last valid packet.
 *   The app must send PING at least every (TIMEOUT_MS − 1000) ms to keep
 *   the session alive. Recommended app PING interval: 1000 ms.
 *
 * Usage:
 *   RadioKit.startSerial(Serial);          // 115200 baud (default)
 *   RadioKit.startSerial(Serial1, 9600);   // custom baud
 */

#ifndef RADIOKIT_SERIAL_H
#define RADIOKIT_SERIAL_H

#include <Arduino.h>
#include "RadioKitTransport.h"

class RadioKitSerialTransport : public RadioKitTransport {
public:
    RadioKitSerialTransport();

    /**
     * Initialise the serial transport.
     * @param stream  Any Arduino Stream (Serial, Serial1, SoftwareSerial, …)
     * @param baud    Baud rate. Pass 0 to skip Serial.begin() (stream pre-inited).
     * @param cb      Packet callback.
     */
    void begin(Stream& stream, uint32_t baud, RK_PacketCallback cb);

    /** Satisfies RadioKitTransport interface; name is unused for serial. */
    void begin(const char* /*name*/, RK_PacketCallback cb) override;

    void update()                                      override;
    void sendPacket(const uint8_t* buf, uint16_t len)  override;
    bool isConnected() const                           override;

    /// Timeout in ms since last valid packet before isConnected() → false.
    static constexpr uint32_t TIMEOUT_MS = 3000;

private:
    Stream*           _stream;
    RK_PacketCallback _cb;
    uint32_t          _lastPacketMs;
    bool              _everReceived;
};

extern RadioKitSerialTransport RadioKitSerialInstance;

#endif // RADIOKIT_SERIAL_H
