/**
 * RadioKitProtocol.h
 * Binary protocol constants, packet building, and CRC-16/CCITT utilities.
 *
 * Protocol v3 packet format:
 *   [0x55][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
 *   LENGTH = total packet bytes
 *   CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) over CMD + PAYLOAD
 */

#ifndef RADIOKIT_PROTOCOL_H
#define RADIOKIT_PROTOCOL_H

#include <Arduino.h>
#include <stdint.h>

// ─────────────────────────────────────────────
//  Packet framing
// ─────────────────────────────────────────────
#define RK_START_BYTE   0x55
#define RK_HEADER_SIZE  4       // START + LENGTH_LO + LENGTH_HI + CMD
#define RK_CRC_SIZE     2
#define RK_MIN_PACKET   6       // header(4) + crc(2)

// ─────────────────────────────────────────────
//  Command IDs (Protocol v3)
// ─────────────────────────────────────────────
#define RK_CMD_GET_CONF   0x01   // App → Arduino: request config
#define RK_CMD_CONF_DATA  0x02   // Arduino → App: config payload
#define RK_CMD_GET_VARS   0x03   // App → Arduino: request variables
#define RK_CMD_VAR_DATA   0x04   // Arduino → App: variable values (full sync)
#define RK_CMD_SET_INPUT  0x05   // App → Arduino: set input values
#define RK_CMD_ACK        0x06   // Both: acknowledge SET_INPUT or VAR_UPDATE
#define RK_CMD_PING       0x07   // App → Arduino: keep-alive ping
#define RK_CMD_PONG       0x08   // Arduino → App: pong
#define RK_CMD_VAR_UPDATE 0x09   // Arduino → App: reliable push of single widget

// ─────────────────────────────────────────────
//  Protocol version (v3)
// ─────────────────────────────────────────────
#define RK_PROTOCOL_VERSION 0x03

// ─────────────────────────────────────────────
//  VAR_UPDATE reliability parameters
// ─────────────────────────────────────────────
#define RK_VAR_UPDATE_TIMEOUT_MS   200
#define RK_VAR_UPDATE_MAX_RETRIES  5

// ─────────────────────────────────────────────
//  Buffer sizes
// ─────────────────────────────────────────────
#define RK_MAX_PACKET_SIZE   768
#define RK_RX_BUFFER_SIZE    256

// ─────────────────────────────────────────────
//  CRC-16/CCITT-FALSE
// ─────────────────────────────────────────────
uint16_t rk_crc16(const uint8_t* data, uint16_t len);

// ─────────────────────────────────────────────
//  Packet builder helpers
// ─────────────────────────────────────────────
uint16_t rk_buildPacket(uint8_t* outBuf,
                        uint8_t  cmd,
                        const uint8_t* payload,
                        uint16_t payloadLen);

uint16_t rk_buildPong(uint8_t* outBuf);
uint16_t rk_buildAck(uint8_t* outBuf, uint8_t seq);

// ─────────────────────────────────────────────
//  Incoming packet parser state machine
// ─────────────────────────────────────────────
bool rk_rxFeedByte(uint8_t byte,
                   uint8_t& outCmd,
                   const uint8_t*& outPayload,
                   uint16_t& outPayloadLen);

void rk_rxReset();

#endif // RADIOKIT_PROTOCOL_H
