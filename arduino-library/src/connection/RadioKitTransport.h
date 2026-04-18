/**
 * RadioKitTransport.h
 * Abstract transport interface for RadioKit.
 *
 * Both BLE and Serial backends implement this interface.
 * RadioKitClass holds a pointer to the active transport and calls
 * only these four methods — no transport-specific code in the core.
 */

#ifndef RADIOKIT_TRANSPORT_H
#define RADIOKIT_TRANSPORT_H

#include <Arduino.h>
#include <stdint.h>

/// Callback signature: called by the transport when a complete,
/// CRC-validated packet has been received.
typedef void (*RK_PacketCallback)(uint8_t cmd,
                                  const uint8_t* payload,
                                  uint16_t payloadLen);

class RadioKitTransport {
public:
    virtual ~RadioKitTransport() {}

    /**
     * Initialise the transport.
     * @param name  Device/service name (used by BLE; ignored by Serial).
     * @param cb    Packet callback invoked on every valid received packet.
     */
    virtual void begin(const char* name, RK_PacketCallback cb) = 0;

    /** Poll for incoming data / handle async events. Call every loop(). */
    virtual void update() = 0;

    /** Transmit a fully-formed RadioKit packet. */
    virtual void sendPacket(const uint8_t* buf, uint16_t len) = 0;

    /** Returns true if a remote peer is currently connected/active. */
    virtual bool isConnected() const = 0;
};

#endif // RADIOKIT_TRANSPORT_H
