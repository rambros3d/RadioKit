/**
 * RadioKit.h
 * Main user-facing header for the RadioKit Arduino library.
 *
 * Include this single header in your sketch:
 *   #include <RadioKit.h>
 *
 * Sketch pattern:
 *   1. Declare widget objects globally (they self-register)
 *   2. Call RadioKit.startBLE() OR RadioKit.startSerial() in setup()
 *   3. Call RadioKit.update() every loop() iteration
 *   4. Read/write widget values directly
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitConfig.h"
#include "RadioKitProtocol.h"
#include "connection/RadioKitTransport.h"
#include "connection/RadioKitBLE.h"
#include "connection/RadioKitSerial.h"

class RadioKit_Widget;

class RadioKitClass {
public:
    RadioKitClass();

    // ── Setup ─────────────────────────────────────────────────────────────

    /**
     * Initialise BLE and start advertising.
     * @param deviceName  Name visible during BLE scanning.
     * @param password    Optional connection password (nullptr = open).
     */
    void startBLE(const char* deviceName, const char* password = nullptr);

    /**
     * Attach to a pre-initialised serial stream.
     * The sketch MUST call Serial.begin() (or equivalent) before this.
     *
     * @param stream  Any Arduino Stream — Serial, Serial1, SoftwareSerial, …
     *
     * Example:
     *   Serial.begin(115200);
     *   RadioKit.startSerial(Serial);
     */
    void startSerial(Stream& stream);

    // ── Main loop ──────────────────────────────────────────────────────────

    /** Process transport events and incoming packets. Call once per loop(). */
    void update();

    // ── Status ─────────────────────────────────────────────────────────────

    /** Returns true if a peer is connected (BLE) or recently active (Serial). */
    bool isConnected() const;

    /** Returns the number of registered widgets. */
    uint8_t widgetCount() const { return _widgetCount; }

    // ── Internal ───────────────────────────────────────────────────────────

    /** Called by RadioKit_Widget constructor to self-register. */
    void _registerWidget(RadioKit_Widget* widget);

private:
    RadioKit_Widget*     _widgets[RADIOKIT_MAX_WIDGETS];
    uint8_t              _widgetCount;
    RadioKit_Orientation _orientation;
    RadioKitTransport*   _transport;

    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    static void _onPacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen);

    void _handleGetConf();
    void _handleGetVars();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handlePing();

    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _totalInputBytes()  const;
    uint16_t _totalOutputBytes() const;
};

extern RadioKitClass RadioKit;

#include "RadioKitWidgets.h"

#endif // RADIOKIT_H
