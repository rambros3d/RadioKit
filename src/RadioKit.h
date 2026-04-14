/**
 * RadioKit.h
 * Main user-facing header for the RadioKit library.
 *
 * Include this single header in your Arduino sketch:
 *   #include <RadioKit.h>
 *
 * Sketch pattern:
 *   1. Declare a config block with RK_CONFIG_BEGIN / RK_CONFIG_END macros
 *   2. Declare a flat struct with one field per widget value
 *   3. Call RadioKit.begin("DeviceName", &myStruct) in setup()
 *   4. Call RadioKit.handle() every loop() iteration
 *   5. Read/write struct fields directly
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitConfig.h"
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
     * Initialise BLE and start advertising.
     *
     * Links the PROGMEM config array (declared with RK_CONFIG_BEGIN/END)
     * to the user's flat control struct. Must be called after the global
     * _rk_conf[] array is in scope.
     *
     * @param deviceName  BLE device name visible during scanning
     * @param structPtr   Pointer to the user's flat control struct
     */
    void begin(const char* deviceName, void* structPtr);

    // ── Main loop ────────────────────────────────────────────────────────────

    /**
     * Process BLE events and protocol messages.
     * Must be called once per loop() iteration.
     */
    void handle();

    // ── Status ───────────────────────────────────────────────────────────────

    /** Returns true if a Flutter app is currently connected. */
    bool isConnected() const;

private:
    // ── Struct sync state ────────────────────────────────────────────────────
    void*    _structPtr;            ///< Pointer to user flat struct
    uint16_t _inputBytes;           ///< Total input variable bytes
    uint16_t _outputBytes;          ///< Total output variable bytes
    uint16_t _connectFlagOffset;    ///< Byte offset of connect_flag in struct
    uint8_t  _widgetCount;          ///< Resolved at begin() from config array
    bool     _confReady;            ///< True after begin() parsed config OK

    // ── TX scratch buffer ────────────────────────────────────────────────────
    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    // ── Config parse ─────────────────────────────────────────────────────────
    /**
     * Walk _rk_conf[] PROGMEM to count widgets and compute
     * _inputBytes, _outputBytes, _connectFlagOffset, _widgetCount.
     */
    void _parseConfig();

    /** Return the input byte size of a widget type. */
    static uint8_t _widgetInputSize(uint8_t typeId);

    /** Return the output byte size of a widget type. */
    static uint8_t _widgetOutputSize(uint8_t typeId);

    // ── Protocol handlers ────────────────────────────────────────────────────
    static void _onPacket(uint8_t cmd,
                          const uint8_t* payload,
                          uint16_t payloadLen);

    void _handleGetConf();
    void _handleGetVars();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handlePing();

    // ── Serialization ────────────────────────────────────────────────────────
    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
};

// ─────────────────────────────────────────────
//  Global singleton (defined in RadioKit.cpp)
// ─────────────────────────────────────────────
extern RadioKitClass RadioKit;

#endif // RADIOKIT_H
