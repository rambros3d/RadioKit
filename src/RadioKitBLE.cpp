/**
 * RadioKitBLE.cpp
 * BLE transport layer implementation using ESP32 Arduino BLE library.
 */

#include "RadioKitBLE.h"
#include "RadioKitProtocol.h"

// ESP32 BLE headers
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ─────────────────────────────────────────────
//  Singleton instance
// ─────────────────────────────────────────────
RadioKitBLE RadioKitBLEInstance;

// ─────────────────────────────────────────────
//  BLE Server callbacks (connection events)
// ─────────────────────────────────────────────
class RKServerCallbacks : public BLEServerCallbacks {
public:
    void onConnect(BLEServer* /*pServer*/) override {
        RadioKitBLEInstance._onConnect();
    }
    void onDisconnect(BLEServer* /*pServer*/) override {
        RadioKitBLEInstance._onDisconnect();
    }
};

// ─────────────────────────────────────────────
//  BLE Characteristic callbacks (data received)
// ─────────────────────────────────────────────
class RKCharCallbacks : public BLECharacteristicCallbacks {
public:
    void onWrite(BLECharacteristic* pChar) override {
        std::string value = pChar->getValue();
        if (!value.empty()) {
            RadioKitBLEInstance._onWrite(
                (const uint8_t*)value.data(),
                value.length()
            );
        }
    }
};

// ─────────────────────────────────────────────
//  RadioKitBLE implementation
// ─────────────────────────────────────────────
RadioKitBLE::RadioKitBLE()
    : _server(nullptr)
    , _characteristic(nullptr)
    , _packetCallback(nullptr)
    , _connected(false)
    , _needRestartAdv(false)
{
}

void RadioKitBLE::begin(const char* deviceName, RK_PacketCallback onPacket) {
    _packetCallback = onPacket;
    _connected      = false;
    _needRestartAdv = false;

    // Initialise BLE stack
    BLEDevice::init(deviceName);

    // Create server
    _server = BLEDevice::createServer();
    _server->setCallbacks(new RKServerCallbacks());

    // Create service
    BLEService* pService = _server->createService(RK_BLE_SERVICE_UUID);

    // Create characteristic with READ + WRITE + NOTIFY properties
    _characteristic = pService->createCharacteristic(
        RK_BLE_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ   |
        BLECharacteristic::PROPERTY_WRITE  |
        BLECharacteristic::PROPERTY_NOTIFY
    );

    // Add CCCD descriptor to enable notifications from the client side
    _characteristic->addDescriptor(new BLE2902());

    // Register write callback
    _characteristic->setCallbacks(new RKCharCallbacks());

    // Start service and begin advertising
    pService->start();

    BLEAdvertising* pAdv = BLEDevice::getAdvertising();
    pAdv->addServiceUUID(RK_BLE_SERVICE_UUID);
    pAdv->setScanResponse(true);
    pAdv->setMinPreferred(0x06);  // iOS connection hint
    pAdv->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
}

void RadioKitBLE::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_connected || !_characteristic) return;

    // Fragment into RK_BLE_MTU-byte chunks
    uint16_t offset = 0;
    while (offset < len) {
        uint16_t chunkLen = len - offset;
        if (chunkLen > RK_BLE_MTU) {
            chunkLen = RK_BLE_MTU;
        }
        _characteristic->setValue(const_cast<uint8_t*>(buf + offset), chunkLen);
        _characteristic->notify();
        offset += chunkLen;

        // Small yield between fragments to avoid overwhelming the BLE stack
        if (offset < len) {
            delay(10);
        }
    }
}

void RadioKitBLE::update() {
    // Restart advertising after a client disconnects
    if (_needRestartAdv) {
        _needRestartAdv = false;
        delay(500); // brief pause before re-advertising
        BLEDevice::startAdvertising();
    }
}

// ─────────────────────────────────────────────
//  Internal callbacks called from BLE event handlers
// ─────────────────────────────────────────────
void RadioKitBLE::_onConnect() {
    _connected = true;
}

void RadioKitBLE::_onDisconnect() {
    _connected      = false;
    _needRestartAdv = true;
    rk_rxReset();  // flush receive parser on disconnect
}

void RadioKitBLE::_onWrite(const uint8_t* data, size_t len) {
    if (!_packetCallback) return;

    uint8_t        cmd;
    const uint8_t* payload;
    uint16_t       payloadLen;

    for (size_t i = 0; i < len; i++) {
        if (rk_rxFeedByte(data[i], cmd, payload, payloadLen)) {
            _packetCallback(cmd, payload, payloadLen);
        }
    }
}
