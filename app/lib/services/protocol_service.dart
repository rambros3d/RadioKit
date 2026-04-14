import 'dart:typed_data';
import 'dart:convert';
import '../models/protocol.dart';
import '../models/widget_config.dart';

/// Result of parsing a CONF_DATA payload.
class ParsedConf {
  final int orientation;        // kOrientationLandscape or kOrientationPortrait
  final List<WidgetConfig> widgets;

  const ParsedConf({required this.orientation, required this.widgets});
}

/// Handles all packet building, parsing, and CRC computation for the
/// RadioKit binary protocol v2.0.
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
    final totalLength = 6 + payloadBytes.length;

    final crcInput = [cmd, ...payloadBytes];
    final crc = _crc16(crcInput);

    final packet = Uint8List(totalLength);
    packet[0] = kStartByte;
    packet[1] = totalLength & 0xFF;
    packet[2] = (totalLength >> 8) & 0xFF;
    packet[3] = cmd;
    for (int i = 0; i < payloadBytes.length; i++) {
      packet[4 + i] = payloadBytes[i] & 0xFF;
    }
    packet[totalLength - 2] = crc & 0xFF;
    packet[totalLength - 1] = (crc >> 8) & 0xFF;

    return packet;
  }

  /// Build a GET_CONF packet (no payload).
  static Uint8List buildGetConf() => buildPacket(kCmdGetConf);

  /// Build a GET_VARS packet (no payload).
  static Uint8List buildGetVars() => buildPacket(kCmdGetVars);

  /// Build a PING packet (no payload).
  static Uint8List buildPing() => buildPacket(kCmdPing);

  /// Build a SET_INPUT packet for the given [widgets] using [state].
  static Uint8List buildSetInput(
      List<WidgetConfig> widgets, RadioWidgetState state) {
    final payload = <int>[];

    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in inputWidgets) {
      final values = state.inputValues[widget.widgetId] ?? [];
      if (widget.typeId == kWidgetJoystick) {
        final x = values.isNotEmpty ? values[0] : 0;
        final y = values.length > 1 ? values[1] : 0;
        payload.add(x < 0 ? x + 256 : x);
        payload.add(y < 0 ? y + 256 : y);
      } else {
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

    if (receivedCrc != computedCrc) return null;

    return ParsedPacket(cmd: cmd, payload: Uint8List.fromList(payload));
  }

  // ---------------------------------------------------------------------------
  // CONF_DATA parsing  (protocol v2)
  // ---------------------------------------------------------------------------

  /// Parse a v2 CONF_DATA payload.
  ///
  /// v2 header: [VERSION(1)] [ORIENTATION(1)] [NUM_WIDGETS(1)]
  ///
  /// Each widget descriptor (8 + labelLen bytes):
  ///   [TYPE_ID(1)] [WIDGET_ID(1)] [X(1)] [Y(1)] [SIZE(1)] [ASPECT(1)]
  ///   [ROTATION(1, int8)] [LABEL_LEN(1)] [LABEL(N)]
  ///
  /// SIZE  = height in canvas units (uint8).
  /// ASPECT = aspectRatio × 10, uint8 (e.g. 25 = 2.5, 10 = 1.0).
  /// Width is computed as: SIZE × (ASPECT / 10.0).
  ///
  /// Returns null on version mismatch or truncated data.
  static ParsedConf? parseConfData(List<int> payload) {
    if (payload.length < 3) return null;

    final version = payload[0];
    if (version != kProtocolVersion) {
      return null;
    }

    final orientation = payload[1];
    final numWidgets  = payload[2];
    final widgets     = <WidgetConfig>[];
    int offset        = 3;

    for (int i = 0; i < numWidgets; i++) {
      if (offset + 8 > payload.length) break;

      final typeId   = payload[offset];
      final widgetId = payload[offset + 1];
      final x        = payload[offset + 2].toDouble();
      final y        = payload[offset + 3].toDouble();
      final size     = payload[offset + 4];           // HEIGHT in canvas units
      final aspect   = payload[offset + 5];           // aspectRatio × 10
      final rotRaw   = payload[offset + 6];
      final rotation = rotRaw >= 128 ? rotRaw - 256 : rotRaw;
      final labelLen = payload[offset + 7];
      offset += 8;

      String label = '';
      if (labelLen > 0 && offset + labelLen <= payload.length) {
        label = utf8.decode(payload.sublist(offset, offset + labelLen),
            allowMalformed: true);
        offset += labelLen;
      }

      widgets.add(WidgetConfig(
        typeId:   typeId,
        widgetId: widgetId,
        x:        x,
        y:        y,
        size:     size,
        aspect:   aspect,
        label:    label,
        rotation: rotation,
      ));
    }

    return ParsedConf(orientation: orientation, widgets: widgets);
  }

  // ---------------------------------------------------------------------------
  // VAR_DATA parsing
  // ---------------------------------------------------------------------------

  /// Parse a VAR_DATA payload, updating [WidgetState] with new values.
  static RadioWidgetState? parseVarData(
      List<int> payload, List<WidgetConfig> widgets, RadioWidgetState current) {
    int offset = 0;

    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));
    final outputWidgets = widgets.where((w) => w.hasOutput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    var state = current;

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

    for (final widget in outputWidgets) {
      if (widget.typeId == kWidgetText) {
        if (offset + 32 > payload.length) break;
        final rawBytes = payload.sublist(offset, offset + 32);
        final nullIdx  = rawBytes.indexOf(0);
        final strBytes = nullIdx >= 0 ? rawBytes.sublist(0, nullIdx) : rawBytes;
        final text     = utf8.decode(strBytes, allowMalformed: true);
        state = state.copyWithOutput(widget.widgetId, text);
        offset += 32;
      } else {
        if (offset + 1 > payload.length) break;
        state = state.copyWithOutput(widget.widgetId, payload[offset]);
        offset += 1;
      }
    }

    return state;
  }

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
  String toString() =>
      'ParsedPacket(cmd=0x${cmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}
