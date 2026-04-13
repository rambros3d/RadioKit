import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/protocol_service.dart';
import 'package:radiokit/models/protocol.dart';

void main() {
  group('ProtocolService', () {
    group('CRC-16/CCITT', () {
      test('builds GET_CONF packet with correct start byte', () {
        final packet = ProtocolService.buildGetConf();
        expect(packet[0], equals(kStartByte)); // START = 0x55
        expect(packet[3], equals(kCmdGetConf)); // CMD = 0x01
      });

      test('builds correct minimum packet length', () {
        final packet = ProtocolService.buildPing();
        // Minimum: 1(start)+2(len)+1(cmd)+2(crc) = 6 bytes
        expect(packet.length, equals(6));
      });

      test('packet length field matches actual packet length', () {
        final packet = ProtocolService.buildGetConf();
        final lengthField = packet[1] | (packet[2] << 8);
        expect(lengthField, equals(packet.length));
      });

      test('parses its own output correctly', () {
        final packet = ProtocolService.buildPing();
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdPing));
        expect(parsed.payload.length, equals(0));
      });

      test('returns null on CRC mismatch', () {
        final packet = ProtocolService.buildPing().toList();
        // Corrupt a CRC byte
        packet[packet.length - 1] ^= 0xFF;
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNull);
      });

      test('returns null on short data', () {
        final parsed = ProtocolService.parsePacket([0x55, 0x06]);
        expect(parsed, isNull);
      });

      test('returns null on wrong start byte', () {
        final packet = ProtocolService.buildPing().toList();
        packet[0] = 0xAA; // Wrong start byte
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNull);
      });
    });

    group('CONF_DATA parsing', () {
      test('returns empty list for zero widgets', () {
        final payload = [0x01, 0x00]; // version=1, count=0
        final widgets = ProtocolService.parseConfData(payload);
        expect(widgets, isNotNull);
        expect(widgets!, isEmpty);
      });

      test('returns null for truncated payload', () {
        final payload = [0x01]; // Missing count byte
        final widgets = ProtocolService.parseConfData(payload);
        expect(widgets, isNull);
      });

      test('parses a single button widget descriptor', () {
        // TYPE(1=btn) ID(5) X(100 LE) Y(200 LE) W(150 LE) H(50 LE) LABEL_LEN(3) LABEL
        final payload = [
          0x01, // version
          0x01, // 1 widget
          0x01, // TYPE = BUTTON
          0x05, // WIDGET_ID = 5
          0x64, 0x00, // X = 100
          0xC8, 0x00, // Y = 200
          0x96, 0x00, // W = 150
          0x32, 0x00, // H = 50
          0x03, // LABEL_LEN = 3
          0x42, 0x54, 0x4E, // "BTN"
        ];
        final widgets = ProtocolService.parseConfData(payload);
        expect(widgets, isNotNull);
        expect(widgets!.length, equals(1));
        expect(widgets[0].typeId, equals(kWidgetButton));
        expect(widgets[0].widgetId, equals(5));
        expect(widgets[0].x, equals(100.0));
        expect(widgets[0].y, equals(200.0));
        expect(widgets[0].w, equals(150.0));
        expect(widgets[0].h, equals(50.0));
        expect(widgets[0].label, equals('BTN'));
      });
    });

    group('SET_INPUT building', () {
      test('builds correct payload for empty widget list', () {
        final packet = ProtocolService.buildSetInput([], _emptyState());
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdSetInput));
        expect(parsed.payload.length, equals(0));
      });
    });
  });
}

// Helper to create an empty WidgetState for tests.
import 'package:radiokit/models/widget_config.dart';

WidgetState _emptyState() {
  return const WidgetState(inputValues: {}, outputValues: {});
}
