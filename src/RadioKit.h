/**
 * RadioKit.h
 * Main user-facing header for the RadioKit Arduino library (v2.0).
 *
 * Sketch pattern:
 *   1. Declare widget objects globally (they self-register)
 *   2. Set RadioKit.config fields
 *   3. Call RadioKit.begin() then RadioKit.startBLE() or RadioKit.startSerial()
 *   4. Call RadioKit.update() every loop()
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitConfig.h"
#include "RadioKitProtocol.h"
#include "connection/RadioKitTransport.h"
#include "connection/RadioKitBLE.h"
#include "connection/RadioKitSerial.h"

class RadioKit_Widget;

// ── Config object ────────────────────────────────────────────
struct RK_Config {
    // ── User configurable ────────────────────────────────────
    const char* name        = "RadioKit Device";
    const char* password    = "";
    const char* description = "";
    const char* version     = "1.0.0";
    const char* type        = "";
    uint8_t     theme       = RK_DEFAULT;
    uint8_t     orientation = RK_LANDSCAPE;
    uint8_t     width       = 0;  ///< Canvas width  (0 = auto)
    uint8_t     height      = 0;  ///< Canvas height (0 = auto)

    // ── Read-only (set by library) ────────────────────────────
    uint8_t     architecture = RK_ARCH_DETECTED;
    const char* libversion   = RK_LIB_VERSION;
};

// ── Main class ───────────────────────────────────────────────
class RadioKitClass {
public:
    RadioKitClass();

    /** Global configuration — set before begin(). */
    RK_Config config;

    // ── Setup ────────────────────────────────────────────────

    /** Commits configuration. Must be called in setup() before startBLE/startSerial. */
    void begin();

    /**
     * Initialise BLE and start advertising.
     * @param deviceName  Overrides config.name for BLE advertising if provided.
     */
    void startBLE(const char* deviceName = nullptr);

    /**
     * Attach to a pre-initialised serial stream.
     * The sketch MUST call Serial.begin() before this.
     */
    void startSerial(Stream& stream);

    // ── Main loop ────────────────────────────────────────────
    void update();

    // ── Status ───────────────────────────────────────────────
    bool    isConnected() const;
    uint8_t widgetCount() const { return _widgetCount; }

    // ── Internal ─────────────────────────────────────────────
    void _registerWidget(RadioKit_Widget* widget);

private:
    RadioKit_Widget*   _widgets[RADIOKIT_MAX_WIDGETS];
    uint8_t            _widgetCount;
    RadioKitTransport* _transport;

    // VAR_UPDATE reliability
    bool    _pendingVarUpdate;
    uint8_t _varUpdateSeq;
    uint8_t _varUpdateId;
    uint8_t _varUpdateRetries;
    uint32_t _varUpdateSentAt;

    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    static void _onPacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen);

    void _handleGetConf();
    void _handleGetVars();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handlePing();
    void _handleAck(const uint8_t* payload, uint16_t len);

    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
};

extern RadioKitClass RadioKit;

#include "RadioKitWidgets.h"

#endif // RADIOKIT_H
