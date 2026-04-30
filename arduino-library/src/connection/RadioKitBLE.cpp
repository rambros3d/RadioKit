/**
 * RadioKitBLE.cpp
 * BLE transport implementation using NimBLE-Arduino.
 */

#include "RadioKitBLE.h"
#include "../RadioKitProtocol.h"
#include <NimBLEDevice.h>

RadioKitBLE RadioKitBLEInstance;

// ── Static Callback Instances (Avoids heap allocation/fragmentation) ──
class RKServerCallbacks : public NimBLEServerCallbacks {
public:
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override { 
        RadioKitBLEInstance._onConnect();
    }
    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override { 
        RadioKitBLEInstance._onDisconnect(); 
    }
};

class RKCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onWrite(value.data(), value.length());
    }
};

static RKServerCallbacks s_serverCallbacks;
static RKCharCallbacks   s_charCallbacks;

// ─────────────────────────────────────────────
RadioKitBLE::RadioKitBLE()
    : _server(nullptr), _characteristic(nullptr)
    , _packetCallback(nullptr), _connected(false), _needRestartAdv(false)
{}

void RadioKitBLE::begin(const char* deviceName, RK_PacketCallback cb) {
    _packetCallback = cb;
    _connected      = false;
    _needRestartAdv = false;

    // Pulse the LED to show we reached begin()
    pinMode(7, OUTPUT);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW); delay(100);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW);

    Serial.println("BLE: Initializing stack...");
    NimBLEDevice::init(deviceName ? deviceName : "RadioKit");
    
    Serial.println("BLE: Creating server...");
    _server = NimBLEDevice::createServer();
    _server->setCallbacks(&s_serverCallbacks);

    Serial.println("BLE: Creating service...");
    NimBLEService* pService = _server->createService(RK_BLE_SERVICE_UUID);

    Serial.println("BLE: Creating characteristic...");
    _characteristic = pService->createCharacteristic(
        RK_BLE_CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::NOTIFY
    );
    _characteristic->setCallbacks(&s_charCallbacks);

    Serial.println("BLE: Starting advertising...");
    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID(RK_BLE_SERVICE_UUID);
    pAdv->enableScanResponse(true);
    pAdv->setName(deviceName ? deviceName : "RadioKit");
    pAdv->setPreferredParams(0x06, 0x12);
    pAdv->start();
    
    Serial.println("BLE: System ready.");
}

void RadioKitBLE::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_connected || !_characteristic) return;
    uint16_t offset = 0;
    while (offset < len) {
        uint16_t chunk = len - offset;
        if (chunk > RK_BLE_MTU) chunk = RK_BLE_MTU;
        _characteristic->setValue(buf + offset, chunk);
        _characteristic->notify();
        offset += chunk;
        if (offset < len) delay(5);
    }
}

void RadioKitBLE::update() {
    if (_needRestartAdv) {
        _needRestartAdv = false;
        delay(500);
        NimBLEDevice::getAdvertising()->start();
    }
}

void RadioKitBLE::_onConnect()    { _connected = true; }
void RadioKitBLE::_onDisconnect() { _connected = false; _needRestartAdv = true; rk_rxReset(); }

void RadioKitBLE::_onWrite(const uint8_t* data, size_t len) {
    if (!_packetCallback) return;
    uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++)
        if (rk_rxFeedByte(data[i], cmd, payload, payloadLen))
            _packetCallback(cmd, payload, payloadLen);
}
