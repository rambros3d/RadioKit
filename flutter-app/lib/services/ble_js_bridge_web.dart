import 'dart:js' as js;
import 'ble_service_impl.dart';

/// Exposes packet injection to JavaScript for the unified Web simulator.
void setupBleJsBridge(BleService service) {
  js.context['injectBlePacket'] = (List<dynamic> bytes) {
    service.injectDebugPacket(bytes.cast<int>());
  };
}
