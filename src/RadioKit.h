/**
 * RadioKit.h
 * Main user-facing header for the RadioKit library.
 *
 * Include this single header in your Arduino sketch:
 *   #include <RadioKit.h>
 *
 * Then instantiate widgets, register them with RadioKit.addWidget(),
 * call RadioKit.begin("DeviceName"), and RadioKit.handle() in loop().
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitWidgets.h"
#include "RadioKitProtocol.h"
#include "connection/RadioKitBLE.h"

// ─────────────────────────────────────────────
//  RadioKitClass — singleton accessed as "RadioKit"
// ─────────────────────────────────────────────
class RadioKitClass {
public:
    RadioKitClass();

    // ── Setup ────────────────────────────────────────────────────────────────

    /**
     * Register a widget with layout information.
     *
     * Widgets must be added before calling begin().
     * Virtual coordinate space is 0–1000 in both axes.
     *
     * @param widget   Reference to a widget object (Button, Slider, etc.)
     * @param label    Human-readable label shown in the app (max 32 chars)
     * @param x        Left edge (0–1000)
     * @param y        Top edge  (0–1000)
     * @param w        Width     (0–1000)
     * @param h        Height    (0–1000)
     */
    void addWidget(RadioKit_Widget& widget,
                   const char* label,
                   uint16_t x, uint16_t y,
                   uint16_t w, uint16_t h);

    /**
     * Initialise BLE and start advertising.
     *
     * @param deviceName  BLE device name visible during scanning (e.g. "MyRobot")
     */
    void begin(const char* deviceName);

    // ── Main loop ────────────────────────────────────────────────────────────

    /**
     * Process BLE events and protocol messages.
     * Call once per loop() iteration.
     */
    void handle();

    // ── Status ───────────────────────────────────────────────────────────────

    /** Returns true if a Flutter app is currently connected */
    bool isConnected() const;

    /** Returns the number of registered widgets */
    uint8_t widgetCount() const { return _widgetCount; }

private:
    // Widget registry
    RadioKit_Widget* _widgets[RADIOKIT_MAX_WIDGETS];
    uint8_t          _widgetCount;

    // Scratch buffer for building outbound packets
    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    // ── Protocol handlers ────────────────────────────────────────────────────

    /** Invoked by BLE layer when a complete, valid packet arrives */
    static void _onPacket(uint8_t cmd,
                          const uint8_t* payload,
                          uint16_t payloadLen);

    void _handleGetConf();
    void _handleGetVars();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handlePing();

    // ── Serialization helpers ─────────────────────────────────────────────────

    /** Build CONF_DATA payload into a scratch buffer; returns byte count */
    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);

    /** Build VAR_DATA payload into a scratch buffer; returns byte count */
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);

    /** Total input variable bytes across all widgets */
    uint16_t _totalInputBytes() const;

    /** Total output variable bytes across all widgets */
    uint16_t _totalOutputBytes() const;
};

// ─────────────────────────────────────────────
//  Global singleton (defined in RadioKit.cpp)
// ─────────────────────────────────────────────
extern RadioKitClass RadioKit;

#endif // RADIOKIT_H
