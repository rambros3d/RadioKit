/// Protocol constants for the RadioKit binary protocol v1.0
library protocol;

// BLE Service and Characteristic UUIDs
const String kRadioKitServiceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
const String kRadioKitCharUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';

// Packet framing
const int kStartByte = 0x55;

// Command identifiers
const int kCmdGetConf = 0x01;
const int kCmdConfData = 0x02;
const int kCmdGetVars = 0x03;
const int kCmdVarData = 0x04;
const int kCmdSetInput = 0x05;
const int kCmdAck = 0x06;
const int kCmdPing = 0x07;
const int kCmdPong = 0x08;

// Widget type identifiers
const int kWidgetButton = 0x01;
const int kWidgetSwitch = 0x02;
const int kWidgetSlider = 0x03;
const int kWidgetJoystick = 0x04;
const int kWidgetLed = 0x05;
const int kWidgetText = 0x06;

// Widget input/output sizes in bytes
const Map<int, int> kWidgetInputSize = {
  kWidgetButton: 1,
  kWidgetSwitch: 1,
  kWidgetSlider: 1,
  kWidgetJoystick: 2,
  kWidgetLed: 0,
  kWidgetText: 0,
};

const Map<int, int> kWidgetOutputSize = {
  kWidgetButton: 0,
  kWidgetSwitch: 0,
  kWidgetSlider: 0,
  kWidgetJoystick: 0,
  kWidgetLed: 1,
  kWidgetText: 32,
};

// Protocol version
const int kProtocolVersion = 0x01;

// Poll intervals
const Duration kGetVarsInterval = Duration(milliseconds: 100);
const Duration kPingInterval = Duration(seconds: 2);
const Duration kConfTimeout = Duration(seconds: 5);

// Virtual coordinate space
const double kVirtualSize = 1000.0;

// Widget type names for display
String widgetTypeName(int typeId) {
  switch (typeId) {
    case kWidgetButton:
      return 'Button';
    case kWidgetSwitch:
      return 'Switch';
    case kWidgetSlider:
      return 'Slider';
    case kWidgetJoystick:
      return 'Joystick';
    case kWidgetLed:
      return 'LED';
    case kWidgetText:
      return 'Text';
    default:
      return 'Unknown';
  }
}
