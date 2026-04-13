/**
 * RadioKitBLE.h
 * BLE transport layer for RadioKit — wraps ESP32 Arduino BLE library.
 *
 * Service UUID  : 0000FFE0-0000-1000-8000-00805F9B34FB
 * Characteristic: 0000FFE1-0000-1000-8000-00805F9B34FB  (read/write/notify)
 *
 * Handles:
 *  - Advertising & connection management
 *  - BLE MTU fragmentation (default 20-byte chunks)
 *  - Feeding received bytes into the protocol parser
 *  - Sending outbound packets (fragmented as needed)
 */

#ifndef RADIOKIT_BLE_H
#define RADIOKIT_BLE_H

#include <Arduino.h>
#include <stdint.h>

// Forward-declare so we don't pull in all of BLE in the header
class BLEServer;
class BLECharacteristic;

// BLE UUIDs
#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

// Maximum bytes per BLE notification (conservative default MTU - 3 overhead)
#define RK_BLE_MTU 20

// ─────────────────────────────────────────────
//  Callback type: called with a fully-parsed packet
// ─────────────────────────────────────────────
typedef void (*RK_PacketCallback)(uint8_t cmd,
                                  const uint8_t* payload,
                                  uint16_t payloadLen);

// ─────────────────────────────────────────────
//  RadioKitBLE class
// ─────────────────────────────────────────────
class RadioKitBLE {
public:
    RadioKitBLE();

    /**
     * Initialise BLE, start advertising with the given device name.
     * @param deviceName  Advertised BLE name (e.g. "MyRobot")
     * @param onPacket    Callback invoked when a complete packet is received
     */
    void begin(const char* deviceName, RK_PacketCallback onPacket);

    /**
     * Send a pre-built packet buffer over BLE notify (fragmented if needed).
     * Does nothing if no client is connected.
     */
    void sendPacket(const uint8_t* buf, uint16_t len);

    /** True if a central is currently connected */
    bool isConnected() const { return _connected; }

    /**
     * Call from RadioKit::handle() every loop iteration.
     * Handles reconnect advertising restart after disconnection.
     */
    void update();

    // --- Internal callbacks (public so C-style BLE callbacks can reach them) ---
    void _onConnect();
    void _onDisconnect();
    void _onWrite(const uint8_t* data, size_t len);

private:
    BLEServer*         _server;
    BLECharacteristic* _characteristic;
    RK_PacketCallback  _packetCallback;
    volatile bool      _connected;
    bool               _needRestartAdv;  // flag set in disconnect callback
};

// ─────────────────────────────────────────────
//  Singleton accessor (used internally by RadioKit.cpp)
// ─────────────────────────────────────────────
extern RadioKitBLE RadioKitBLEInstance;

#endif // RADIOKIT_BLE_H
