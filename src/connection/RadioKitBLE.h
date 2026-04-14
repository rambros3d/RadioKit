/**
 * RadioKitBLE.h
 * BLE transport layer for RadioKit — wraps NimBLE library.
 */

#ifndef RADIOKIT_BLE_H
#define RADIOKIT_BLE_H

#include <Arduino.h>
#include <stdint.h>

// Forward declarations of NimBLE classes
class NimBLEServer;
class NimBLECharacteristic;

// BLE UUIDs
#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

// Maximum bytes per BLE notification (conservative default MTU - 3 overhead)
#define RK_BLE_MTU 20

typedef void (*RK_PacketCallback)(uint8_t cmd,
                                  const uint8_t* payload,
                                  uint16_t payloadLen);

class RadioKitBLE {
public:
    RadioKitBLE();

    void begin(const char* deviceName, RK_PacketCallback onPacket);
    void sendPacket(const uint8_t* buf, uint16_t len);
    bool isConnected() const { return _connected; }
    void update();

    // Internal callbacks
    void _onConnect();
    void _onDisconnect();
    void _onWrite(const uint8_t* data, size_t len);

private:
    NimBLEServer*         _server;
    NimBLECharacteristic* _characteristic;
    RK_PacketCallback  _packetCallback;
    volatile bool      _connected;
    bool               _needRestartAdv;
};

extern RadioKitBLE RadioKitBLEInstance;

#endif // RADIOKIT_BLE_H
