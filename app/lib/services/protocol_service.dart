import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/protocol.dart';
import '../models/widget_config.dart';

/// Result of parsing a CONF_DATA payload.
class ParsedConf {
  final String name;
  final String theme;
  final int orientation;
  final List<WidgetConfig> widgets;
  const ParsedConf({
    required this.name,
    required this.theme,
    required this.orientation,
    required this.widgets,
  });
}

/// Handles all packet building, parsing, and CRC computation for the
/// RadioKit binary protocol v3.0.
class ProtocolService {
  // ── CRC-16/CCITT-FALSE  (poly 0x1021, init 0xFFFF) ──────────────────────

  static int _crc16(List<int> data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= (byte & 0xFF) << 8;
      for (int i = 0; i < 8; i++) {
        crc = ((crc & 0x8000) != 0)
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }

  // ── Packet building ──────────────────────────────────────────────────────

  /// Build a complete RadioKit packet:
  ///   START(1) + LENGTH(2 LE) + CMD(1) + PAYLOAD(N) + CRC(2 LE)
  static Uint8List buildPacket(int cmd, [List<int>? payload]) {
    final p     = payload ?? [];
    final total = 6 + p.length;
    final crc   = _crc16([cmd, ...p]);
    final pkt   = Uint8List(total);
    pkt[0] = kStartByte;
    pkt[1] = total & 0xFF;
    pkt[2] = (total >> 8) & 0xFF;
    pkt[3] = cmd;
    for (int i = 0; i < p.length; i++) pkt[4 + i] = p[i] & 0xFF;
    pkt[total - 2] = crc & 0xFF;
    pkt[total - 1] = (crc >> 8) & 0xFF;
    return pkt;
  }

  static Uint8List buildGetConf()  => buildPacket(kCmdGetConf);
  static Uint8List buildGetVars()  => buildPacket(kCmdGetVars);
  static Uint8List buildPing()     => buildPacket(kCmdPing);

  /// Build an ACK packet acknowledging a VAR_UPDATE with [seq].
  static Uint8List buildAck(int seq) => buildPacket(kCmdAck, [seq & 0xFF]);

  /// Build a VAR_UPDATE packet: [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  static Uint8List buildVarUpdate(int widgetId, int seq, List<int> values) =>
      buildPacket(kCmdVarUpdate, [widgetId & 0xFF, seq & 0xFF, ...values]);

  /// Build a SET_INPUT packet from the full widget state.
  static Uint8List buildSetInput(
      List<WidgetConfig> widgets, RadioWidgetState state) {
    final payload = <int>[];
    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in inputWidgets) {
      final values = state.inputValues[widget.widgetId] ?? [];
      if (widget.typeId == kWidgetJoystick) {
        final x = values.isNotEmpty ? values[0] : 0;
        final y = values.length > 1  ? values[1] : 0;
        payload.add(x < 0 ? x + 256 : x);
        payload.add(y < 0 ? y + 256 : y);
      } else {
        payload.add((values.isNotEmpty ? values[0] : 0) & 0xFF);
      }
    }
    return buildPacket(kCmdSetInput, payload);
  }

  // ── Packet parsing ────────────────────────────────────────────────────────

  static ParsedPacket? parsePacket(List<int> data) {
    if (data.length < 6) return null;
    if (data[0] != kStartByte) return null;
    final length = data[1] | (data[2] << 8);
    if (data.length < length) return null;
    final cmd        = data[3];
    final payloadEnd = length - 2;
    final payload    = data.sublist(4, payloadEnd);
    final rxCrc      = data[payloadEnd] | (data[payloadEnd + 1] << 8);
    if (rxCrc != _crc16([cmd, ...payload])) return null;
    return ParsedPacket(cmd: cmd, payload: Uint8List.fromList(payload));
  }

  // ── CONF_DATA parsing (protocol v3) ─────────────────────────────────────
  //
  // Global header (variable length):
  //   [VERSION(1)] [ORIENTATION(1)] [NUM_WIDGETS(1)]
  //   [NAME_LEN(1)] [NAME(NAME_LEN)]
  //   [PWD_LEN(1)]  [PWD(PWD_LEN)]
  //   [THEME_LEN(1)] [THEME(THEME_LEN)]
  //
  // Per widget — 10 fixed bytes:
  //   [TYPE(1)] [ID(1)] [X(1)] [Y(1)] [SCALE(1)] [ASPECT(1)]
  //   [ROT_LO(1)] [ROT_HI(1)] [STYLE(1)] [VARIANT(1)]
  // Then string section:
  //   [STR_MASK(1)] then for each set bit → [LEN(1)][STR(LEN)]
  //   bit order: LABEL(0), ICON(1), ONTEXT(2), OFFTEXT(3), CONTENT(4)

  static ParsedConf? parseConfData(List<int> payload) {
    if (payload.length < 6) {
      debugPrint('RadioKit CONF_DATA: payload too short (${payload.length} bytes)');
      return null;
    }

    if (payload[0] != kProtocolVersion) {
      debugPrint(
          'RadioKit CONF_DATA: version mismatch '
          '(got 0x${payload[0].toRadixString(16)}, '
          'expected 0x${kProtocolVersion.toRadixString(16)})');
      return null;
    }

    final orientation = payload[1];
    final numWidgets  = payload[2];
    int offset        = 3;

    // Skip device name
    if (offset >= payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated before NAME_LEN');
      return null;
    }
    final nameLen = payload[offset++];
    if (offset + nameLen > payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated in NAME field');
      return null;
    }
    final name = utf8.decode(payload.sublist(offset, offset + nameLen),
        allowMalformed: true);
    offset += nameLen;

    // Skip password
    if (offset >= payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated before PWD_LEN');
      return null;
    }
    final pwdLen = payload[offset++];
    if (offset + pwdLen > payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated in PWD field');
      return null;
    }
    offset += pwdLen;

    // Parse theme string
    if (offset >= payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated before THEME_LEN');
      return null;
    }
    final themeLen = payload[offset++];
    if (offset + themeLen > payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated in THEME field');
      return null;
    }
    final theme = utf8.decode(payload.sublist(offset, offset + themeLen),
        allowMalformed: true);
    offset += themeLen;

    final widgets = <WidgetConfig>[];

    for (int i = 0; i < numWidgets; i++) {
      if (offset + 10 > payload.length) {
        debugPrint('RadioKit CONF_DATA: truncated at widget $i fixed header '
            '(offset=$offset, payload=${payload.length})');
        break;
      }

      final typeId   = payload[offset];
      final widgetId = payload[offset + 1];
      final x        = payload[offset + 2].toDouble();
      final y        = payload[offset + 3].toDouble();
      final scale    = payload[offset + 4]; // ×10  e.g. 20 = 2.0×
      final aspect   = payload[offset + 5]; // ×10  e.g. 0 = use type default
      // Rotation: signed LE int16
      final rotRaw   = payload[offset + 6] | (payload[offset + 7] << 8);
      final rotation = rotRaw >= 0x8000 ? rotRaw - 0x10000 : rotRaw;
      final style    = payload[offset + 8];
      final variant  = payload[offset + 9];
      offset += 10;

      if (offset >= payload.length) {
        debugPrint('RadioKit CONF_DATA: truncated before STR_MASK at widget $i');
        break;
      }
      final strMask = payload[offset++];

      String label = '', icon = '', onText = '', offText = '', content = '';

      String readStr() {
        if (offset >= payload.length) return '';
        final len = payload[offset++];
        if (len == 0) return '';
        if (offset + len > payload.length) {
          offset = payload.length;
          return '';
        }
        final s = utf8.decode(payload.sublist(offset, offset + len),
            allowMalformed: true);
        offset += len;
        return s;
      }

      if ((strMask & kStrMaskLabel)   != 0) label   = readStr();
      if ((strMask & kStrMaskIcon)    != 0) icon    = readStr();
      if ((strMask & kStrMaskOnText)  != 0) onText  = readStr();
      if ((strMask & kStrMaskOffText) != 0) offText = readStr();
      if ((strMask & kStrMaskContent) != 0) content = readStr();

      widgets.add(WidgetConfig(
        typeId:   typeId,
        widgetId: widgetId,
        x:        x,
        y:        y,
        scale:    scale,
        aspect:   aspect,
        rotation: rotation,
        style:    style,
        variant:  variant,
        strMask:  strMask,
        label:    label,
        icon:     icon,
        onText:   onText,
        offText:  offText,
        content:  content,
      ));

      debugPrint('  widget[$i]: ${widgets.last}');
    }

    debugPrint('RadioKit CONF_DATA: parsed ${widgets.length}/$numWidgets widgets OK');
    return ParsedConf(
      name: name,
      theme: theme,
      orientation: orientation,
      widgets: widgets,
    );
  }

  // ── VAR_DATA parsing ─────────────────────────────────────────────────────

  static RadioWidgetState? parseVarData(
      List<int> payload, List<WidgetConfig> widgets, RadioWidgetState current) {
    int offset = 0;
    var state  = current;

    final outputWidgets = widgets.where((w) => w.hasOutput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in outputWidgets) {
      if (widget.typeId == kWidgetText) {
        if (offset + 32 > payload.length) break;
        final raw     = payload.sublist(offset, offset + 32);
        final nullIdx = raw.indexOf(0);
        final text    = utf8.decode(
            nullIdx >= 0 ? raw.sublist(0, nullIdx) : raw,
            allowMalformed: true);
        state = state.copyWithOutput(widget.widgetId, text);
        offset += 32;
      } else if (widget.typeId == kWidgetLed) {
        // v3: LED output = 5 bytes [STATE, R, G, B, OPACITY]
        if (offset + 5 > payload.length) break;
        final led = List<int>.from(payload.sublist(offset, offset + 5));
        state = state.copyWithOutput(widget.widgetId, led);
        offset += 5;
      } else {
        if (offset + 1 > payload.length) break;
        state = state.copyWithOutput(widget.widgetId, payload[offset]);
        offset += 1;
      }
    }

    return state;
  }

  /// Parse a VAR_UPDATE payload: [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  static (int, int, List<int>)? parseVarUpdate(List<int> payload) {
    if (payload.length < 2) return null;
    final widgetId = payload[0];
    final seq      = payload[1];
    final values   = payload.sublist(2);
    return (widgetId, seq, values);
  }

  static int _signed(int byte) {
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
