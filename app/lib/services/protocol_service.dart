import 'dart:typed_data';
import 'dart:convert';
import '../models/protocol.dart';
import '../models/widget_config.dart';

/// Handles all packet building, parsing, and CRC computation for the
/// RadioKit binary protocol v1.0.
class ProtocolService {
  // ---------------------------------------------------------------------------
  // CRC-16/CCITT  (poly 0x1021, init 0xFFFF)
  // ---------------------------------------------------------------------------

  static int _crc16(List<int> data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= (byte & 0xFF) << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  // ---------------------------------------------------------------------------
  // Packet building
  // ---------------------------------------------------------------------------

  /// Build a complete RadioKit packet for [cmd] with optional [payload].
  ///
  /// Layout: START(1) + LENGTH(2 LE) + CMD(1) + PAYLOAD(N) + CRC(2 LE)
  static Uint8List buildPacket(int cmd, [List<int>? payload]) {
    final payloadBytes = payload ?? [];
    // Total length = 1 (start) + 2 (length) + 1 (cmd) + N (payload) + 2 (crc)
    final totalLength = 6 + payloadBytes.length;

    // Compute CRC over CMD + PAYLOAD
    final crcInput = [cmd, ...payloadBytes];
    final crc = _crc16(crcInput);

    final packet = Uint8List(totalLength);
    packet[0] = kStartByte;
    packet[1] = totalLength & 0xFF; // LENGTH_LO
    packet[2] = (totalLength >> 8) & 0xFF; // LENGTH_HI
    packet[3] = cmd;
    for (int i = 0; i < payloadBytes.length; i++) {
      packet[4 + i] = payloadBytes[i] & 0xFF;
    }
    packet[totalLength - 2] = crc & 0xFF; // CRC_LO
    packet[totalLength - 1] = (crc >> 8) & 0xFF; // CRC_HI

    return packet;
  }

  /// Build a GET_CONF packet (no payload).
  static Uint8List buildGetConf() => buildPacket(kCmdGetConf);

  /// Build a GET_VARS packet (no payload).
  static Uint8List buildGetVars() => buildPacket(kCmdGetVars);

  /// Build a PING packet (no payload).
  static Uint8List buildPing() => buildPacket(kCmdPing);

  /// Build a SET_INPUT packet for the given [widgets] using [state].
  ///
  /// The payload packs all input variables in widget-ID order.
  static Uint8List buildSetInput(
      List<WidgetConfig> widgets, RadioWidgetState state) {
    final payload = <int>[];

    // Sort widgets by widgetId to maintain registration order
    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in inputWidgets) {
      final values = state.inputValues[widget.widgetId] ?? [];
      if (widget.typeId == kWidgetJoystick) {
        // Two int8 values: x, y
        final x = values.isNotEmpty ? values[0] : 0;
        final y = values.length > 1 ? values[1] : 0;
        // Convert to unsigned byte (two's complement)
        payload.add(x < 0 ? x + 256 : x);
        payload.add(y < 0 ? y + 256 : y);
      } else {
        // Single byte value
        final v = values.isNotEmpty ? values[0] : 0;
        payload.add(v & 0xFF);
      }
    }

    return buildPacket(kCmdSetInput, payload);
  }

  // ---------------------------------------------------------------------------
  // Packet parsing
  // ---------------------------------------------------------------------------

  /// Parse a received byte stream into a [ParsedPacket], or null if invalid.
  ///
  /// Returns null on:
  ///   - Wrong start byte
  ///   - Insufficient data
  ///   - CRC mismatch
  static ParsedPacket? parsePacket(List<int> data) {
    if (data.length < 6) return null;
    if (data[0] != kStartByte) return null;

    final length = data[1] | (data[2] << 8);
    if (data.length < length) return null;

    final cmd = data[3];
    final payloadEnd = length - 2;
    final payload = data.sublist(4, payloadEnd);

    final receivedCrc = data[payloadEnd] | (data[payloadEnd + 1] << 8);
    final computedCrc = _crc16([cmd, ...payload]);

    if (receivedCrc != computedCrc) {
      // CRC mismatch — drop packet
      return null;
    }

    return ParsedPacket(cmd: cmd, payload: Uint8List.fromList(payload));
  }

  // ---------------------------------------------------------------------------
  // CONF_DATA parsing
  // ---------------------------------------------------------------------------

  /// Parse a CONF_DATA payload into a list of [WidgetConfig] objects.
  ///
  /// Payload format:
  ///   [VERSION(1)] [NUM_WIDGETS(1)] [WIDGET_1] ... [WIDGET_N]
  ///
  /// Each widget:
  ///   [TYPE_ID(1)] [WIDGET_ID(1)] [X(2 LE)] [Y(2 LE)] [W(2 LE)] [H(2 LE)]
  ///   [LABEL_LEN(1)] [LABEL(N)]
  static List<WidgetConfig>? parseConfData(List<int> payload) {
    if (payload.length < 2) return null;

    final version = payload[0];
    if (version != kProtocolVersion) {
      // Incompatible protocol version — still attempt parsing
    }

    final numWidgets = payload[1];
    final widgets = <WidgetConfig>[];
    int offset = 2;

    for (int i = 0; i < numWidgets; i++) {
      // Need at least 11 bytes: type(1)+id(1)+x(2)+y(2)+w(2)+h(2)+labelLen(1)
      if (offset + 11 > payload.length) break;

      final typeId = payload[offset];
      final widgetId = payload[offset + 1];
      final x = payload[offset + 2] | (payload[offset + 3] << 8);
      final y = payload[offset + 4] | (payload[offset + 5] << 8);
      final w = payload[offset + 6] | (payload[offset + 7] << 8);
      final h = payload[offset + 8] | (payload[offset + 9] << 8);
      final labelLen = payload[offset + 10];
      offset += 11;

      String label = '';
      if (labelLen > 0 && offset + labelLen <= payload.length) {
        label = utf8.decode(payload.sublist(offset, offset + labelLen),
            allowMalformed: true);
        offset += labelLen;
      }

      widgets.add(WidgetConfig(
        typeId: typeId,
        widgetId: widgetId,
        x: x.toDouble(),
        y: y.toDouble(),
        w: w.toDouble(),
        h: h.toDouble(),
        label: label,
      ));
    }

    return widgets;
  }

  // ---------------------------------------------------------------------------
  // VAR_DATA parsing
  // ---------------------------------------------------------------------------

  /// Parse a VAR_DATA payload, updating the [WidgetState] with new values.
  ///
  /// Layout: [INPUT_VARS...] [OUTPUT_VARS...]
  /// Variables are packed in widget-ID order, sizes per widget type.
  static RadioWidgetState? parseVarData(
      List<int> payload, List<WidgetConfig> widgets, RadioWidgetState current) {
    int offset = 0;

    // Sort by widgetId to match registration order
    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));
    final outputWidgets = widgets.where((w) => w.hasOutput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    var state = current;

    // Parse input variables
    for (final widget in inputWidgets) {
      if (widget.typeId == kWidgetJoystick) {
        if (offset + 2 > payload.length) break;
        final x = _toSigned(payload[offset]);
        final y = _toSigned(payload[offset + 1]);
        state = state.copyWithInput(widget.widgetId, [x, y]);
        offset += 2;
      } else {
        if (offset + 1 > payload.length) break;
        state = state.copyWithInput(widget.widgetId, [payload[offset]]);
        offset += 1;
      }
    }

    // Parse output variables
    for (final widget in outputWidgets) {
      if (widget.typeId == kWidgetText) {
        if (offset + 32 > payload.length) break;
        final rawBytes = payload.sublist(offset, offset + 32);
        // Find null terminator
        final nullIdx = rawBytes.indexOf(0);
        final strBytes =
            nullIdx >= 0 ? rawBytes.sublist(0, nullIdx) : rawBytes;
        final text = utf8.decode(strBytes, allowMalformed: true);
        state = state.copyWithOutput(widget.widgetId, text);
        offset += 32;
      } else {
        // LED: 1 byte
        if (offset + 1 > payload.length) break;
        state = state.copyWithOutput(widget.widgetId, payload[offset]);
        offset += 1;
      }
    }

    return state;
  }

  /// Convert an unsigned byte value (0-255) to a signed int8 (-128..127).
  static int _toSigned(int byte) {
    final b = byte & 0xFF;
    return b >= 128 ? b - 256 : b;
  }
}

/// Result of a successfully parsed packet.
class ParsedPacket {
  final int cmd;
  final Uint8List payload;

  const ParsedPacket({required this.cmd, required this.payload});

  @override
  String toString() => 'ParsedPacket(cmd=0x${cmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}
