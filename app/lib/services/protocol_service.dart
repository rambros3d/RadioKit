import 'dart:typed_data';
import 'dart:convert';
import '../models/protocol.dart';
import '../models/widget_config.dart';

/// Result of parsing a CONF_DATA payload.
class ParsedConf {
  final int orientation;
  final List<WidgetConfig> widgets;
  const ParsedConf({required this.orientation, required this.widgets});
}

/// Handles all packet building, parsing, and CRC computation for the
/// RadioKit binary protocol v3.0.
class ProtocolService {
  // ── CRC-16/CCITT  (poly 0x1021, init 0xFFFF) ────────────────────────────

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

  /// Build a complete RadioKit packet: START(1)+LENGTH(2 LE)+CMD(1)+PAYLOAD(N)+CRC(2 LE)
  static Uint8List buildPacket(int cmd, [List<int>? payload]) {
    final p    = payload ?? [];
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

  static Uint8List buildGetConf() => buildPacket(kCmdGetConf);
  static Uint8List buildGetVars() => buildPacket(kCmdGetVars);
  static Uint8List buildPing()    => buildPacket(kCmdPing);

  /// Build an ACK packet acknowledging a VAR_UPDATE with [seq].
  static Uint8List buildAck(int seq) => buildPacket(kCmdAck, [seq & 0xFF]);

  /// Build a VAR_UPDATE packet: [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  static Uint8List buildVarUpdate(int widgetId, int seq, List<int> values) {
    return buildPacket(kCmdVarUpdate, [widgetId & 0xFF, seq & 0xFF, ...values]);
  }

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
        final y = values.length > 1 ? values[1] : 0;
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

  // ── CONF_DATA parsing (protocol v3) ──────────────────────────────────────
  //
  // v3 header:  [VERSION(1)] [ORIENTATION(1)] [NUM_WIDGETS(1)]
  //
  // Per widget: [TYPE_ID(1)] [WIDGET_ID(1)] [X(1)] [Y(1)] [SIZE(1)]
  //             [ASPECT(1)] [SCALE(1)] [ROTATION(1,int8)]
  //             [STYLE(1)] [VARIANT(1)] [STR_MASK(1)]
  //             then for each set bit in STR_MASK: [LEN(1)] [STR(LEN)]
  //             order: LABEL, ICON, ONTEXT, OFFTEXT, CONTENT

  static ParsedConf? parseConfData(List<int> payload) {
    if (payload.length < 3) return null;
    if (payload[0] != kProtocolVersion) return null;

    final orientation = payload[1];
    final numWidgets  = payload[2];
    final widgets     = <WidgetConfig>[];
    int offset        = 3;

    for (int i = 0; i < numWidgets; i++) {
      if (offset + 11 > payload.length) break;

      final typeId   = payload[offset];
      final widgetId = payload[offset + 1];
      final x        = payload[offset + 2].toDouble();
      final y        = payload[offset + 3].toDouble();
      final size     = payload[offset + 4];
      final aspect   = payload[offset + 5];
      final scale    = payload[offset + 6];
      final rotRaw   = payload[offset + 7];
      final rotation = rotRaw >= 128 ? rotRaw - 256 : rotRaw;
      final style    = payload[offset + 8];
      final variant  = payload[offset + 9];
      final strMask  = payload[offset + 10];
      offset += 11;

      String label = '', icon = '', onText = '', offText = '', content = '';

      String _readStr() {
        if (offset >= payload.length) return '';
        final len = payload[offset++];
        if (len == 0 || offset + len > payload.length) return '';
        final s = utf8.decode(payload.sublist(offset, offset + len),
            allowMalformed: true);
        offset += len;
        return s;
      }

      if (strMask & kStrMaskLabel   != 0) label   = _readStr();
      if (strMask & kStrMaskIcon    != 0) icon    = _readStr();
      if (strMask & kStrMaskOnText  != 0) onText  = _readStr();
      if (strMask & kStrMaskOffText != 0) offText = _readStr();
      if (strMask & kStrMaskContent != 0) content = _readStr();

      widgets.add(WidgetConfig(
        typeId:   typeId,
        widgetId: widgetId,
        x:        x,
        y:        y,
        size:     size,
        aspect:   aspect,
        scale:    scale,
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
    }

    return ParsedConf(orientation: orientation, widgets: widgets);
  }

  // ── VAR_DATA parsing ──────────────────────────────────────────────────────

  static RadioWidgetState? parseVarData(
      List<int> payload, List<WidgetConfig> widgets, RadioWidgetState current) {
    int offset = 0;
    var state  = current;

    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));
    final outputWidgets = widgets.where((w) => w.hasOutput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in inputWidgets) {
      if (widget.typeId == kWidgetJoystick) {
        if (offset + 2 > payload.length) break;
        final x = _signed(payload[offset]);
        final y = _signed(payload[offset + 1]);
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
        final raw     = payload.sublist(offset, offset + 32);
        final nullIdx = raw.indexOf(0);
        final text    = utf8.decode(
            nullIdx >= 0 ? raw.sublist(0, nullIdx) : raw,
            allowMalformed: true);
        state = state.copyWithOutput(widget.widgetId, text);
        offset += 32;
      } else if (widget.typeId == kWidgetLed) {
        // v3: LED output = 4 bytes [R, G, B, OPACITY]
        if (offset + 4 > payload.length) break;
        final rgba = payload.sublist(offset, offset + 4);
        state = state.copyWithOutput(widget.widgetId, List<int>.from(rgba));
        offset += 4;
      } else {
        if (offset + 1 > payload.length) break;
        state = state.copyWithOutput(widget.widgetId, payload[offset]);
        offset += 1;
      }
    }

    return state;
  }

  /// Parse a VAR_UPDATE payload: [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  /// Returns (widgetId, seq, values) or null if malformed.
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
