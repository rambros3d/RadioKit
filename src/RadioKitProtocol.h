/**
 * RadioKitProtocol.h
 * Binary protocol constants, packet building, and CRC-16/CCITT utilities.
 *
 * Packet format:
 *   [0x55][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
 *   LENGTH = total packet bytes (header + cmd + payload + crc)
 *   CRC-16/CCITT (poly 0x1021, init 0xFFFF) computed over CMD + PAYLOAD
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
#define RK_MIN_PACKET   6       // header (4) + no payload + crc (2)

// ─────────────────────────────────────────────
//  Command IDs
// ─────────────────────────────────────────────
#define RK_CMD_GET_CONF   0x01   // App → Arduino: request config
#define RK_CMD_CONF_DATA  0x02   // Arduino → App: config payload
#define RK_CMD_GET_VARS   0x03   // App → Arduino: request variables
#define RK_CMD_VAR_DATA   0x04   // Arduino → App: variable values
#define RK_CMD_SET_INPUT  0x05   // App → Arduino: set input values
#define RK_CMD_ACK        0x06   // Arduino → App: acknowledgment
#define RK_CMD_PING       0x07   // App → Arduino: keep-alive ping
#define RK_CMD_PONG       0x08   // Arduino → App: keep-alive pong

// ─────────────────────────────────────────────
//  Protocol version sent in CONF_DATA
// ─────────────────────────────────────────────
#define RK_PROTOCOL_VERSION 0x01

// ─────────────────────────────────────────────
//  Maximum outbound buffer (CONF_DATA can be large)
//  16 widgets × (1+1+2+2+2+2+1+32) = 16 × 43 = 688 bytes + overhead
// ─────────────────────────────────────────────
#define RK_MAX_PACKET_SIZE  768

// ─────────────────────────────────────────────
//  Inbound receive buffer (for fragmented BLE reads)
// ─────────────────────────────────────────────
#define RK_RX_BUFFER_SIZE  256

// ─────────────────────────────────────────────
//  CRC-16/CCITT
// ─────────────────────────────────────────────

/**
 * Compute CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF)
 * over `len` bytes starting at `data`.
 */
uint16_t rk_crc16(const uint8_t* data, uint16_t len);

// ─────────────────────────────────────────────
//  Packet builder helpers
// ─────────────────────────────────────────────

/**
 * Write a complete framed packet into `outBuf`.
 *
 * @param outBuf   Destination buffer (must be >= RK_MAX_PACKET_SIZE)
 * @param cmd      Command byte
 * @param payload  Payload bytes (may be nullptr if payloadLen == 0)
 * @param payloadLen Number of payload bytes
 * @return Total packet size written into outBuf
 */
uint16_t rk_buildPacket(uint8_t* outBuf,
                        uint8_t  cmd,
                        const uint8_t* payload,
                        uint16_t payloadLen);

/**
 * Build and return a PONG packet (no payload).
 * Convenience wrapper around rk_buildPacket.
 */
uint16_t rk_buildPong(uint8_t* outBuf);

/**
 * Build and return an ACK packet (no payload).
 */
uint16_t rk_buildAck(uint8_t* outBuf);

// ─────────────────────────────────────────────
//  Incoming packet parser state machine
// ─────────────────────────────────────────────

/**
 * Feed a single received byte into the parser.
 *
 * Call this in the BLE receive callback for every incoming byte.
 * When a complete, valid packet is assembled the function returns true
 * and fills `outCmd` + `outPayload`/`outPayloadLen`.
 *
 * @param byte           The received byte
 * @param outCmd         [out] Parsed command if function returns true
 * @param outPayload     [out] Pointer into internal buffer — valid until next call
 * @param outPayloadLen  [out] Payload byte count
 * @return true if a complete valid packet has been received
 */
bool rk_rxFeedByte(uint8_t byte,
                   uint8_t& outCmd,
                   const uint8_t*& outPayload,
                   uint16_t& outPayloadLen);

/**
 * Reset the receive parser (e.g. on BLE disconnect).
 */
void rk_rxReset();

#endif // RADIOKIT_PROTOCOL_H
