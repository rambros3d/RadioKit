/// Protocol constants for the RadioKit binary protocol v3.0
library protocol;

// BLE Service and Characteristic UUIDs
const String kRadioKitServiceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
const String kRadioKitCharUuid    = '0000FFE1-0000-1000-8000-00805F9B34FB';

// Packet framing
const int kStartByte = 0x55;

// Command identifiers  (must match RadioKitProtocol.h exactly)
const int kCmdGetConf  = 0x01;  // App → Device : request config
const int kCmdConfData = 0x02;  // Device → App : config payload
const int kCmdGetVars  = 0x03;  // App → Device : request variables
const int kCmdVarData  = 0x04;  // Device → App : variable state response
const int kCmdSetInput = 0x05;  // Device → App : firmare-originated physical input sync
const int kCmdAck      = 0x06;  // Both         : acknowledge
const int kCmdPing     = 0x07;  // App → Device : keep-alive ping
const int kCmdPong     = 0x08;  // Device → App : pong
const int kCmdVarUpdate = 0x09; // Both         : precise partial update

// Widget type identifiers
const int kWidgetButton   = 0x01;
const int kWidgetSwitch   = 0x02;
const int kWidgetSlider   = 0x03;
const int kWidgetJoystick = 0x04;
const int kWidgetLed      = 0x05;
const int kWidgetText     = 0x06;
const int kWidgetMultiple = 0x07;
const int kWidgetSlideSwitch = 0x08;

// Widget input sizes in bytes (app → device)
const Map<int, int> kWidgetInputSize = {
  kWidgetButton:      1,
  kWidgetSwitch:      1,
  kWidgetSlider:      1,
  kWidgetJoystick:    2,
  kWidgetLed:         0,
  kWidgetText:        0,
  kWidgetMultiple:    1,
  kWidgetSlideSwitch: 1,
};

// Widget output sizes in bytes (device → app)
// LED v3: 5 bytes — STATE(1) R(1) G(1) B(1) OPACITY(1)
const Map<int, int> kWidgetOutputSize = {
  kWidgetButton:      0,
  kWidgetSwitch:      0,
  kWidgetSlider:      0,
  kWidgetJoystick:    0,
  kWidgetLed:         5,
  kWidgetText:        32,
  kWidgetMultiple:    0,
  kWidgetSlideSwitch: 0,
};

// Default aspect × 10 per widget type (mirrors Arduino defaultAspect())
const Map<int, int> kWidgetDefaultAspect = {
  kWidgetButton:      10,  // 1.0 (square)
  kWidgetSwitch:      10,  // 1.0
  kWidgetSlider:      50,  // 5.0 (wide)
  kWidgetJoystick:    10,  // 1.0 (square)
  kWidgetLed:         10,  // 1.0
  kWidgetText:        30,  // 3.0 (wide)
  kWidgetMultiple:    20,  // 2.0
  kWidgetSlideSwitch: 25,  // 2.5 (wide track)
};

// Protocol version
const int kProtocolVersion = 0x03;

// Orientation wire values
const int kOrientationLandscape = 0x00;
const int kOrientationPortrait  = 0x01;

// Virtual canvas dimensions per orientation
const double kCanvasLandscapeW = 200.0;
const double kCanvasLandscapeH = 100.0;
const double kCanvasPortraitW  = 100.0;
const double kCanvasPortraitH  = 200.0;

// Poll intervals
const Duration kGetVarsInterval = Duration(milliseconds: 250);
const Duration kPingInterval    = Duration(seconds: 2);
// Increased to 8 s to handle slow USB CDC enumeration on some boards
const Duration kConfTimeout     = Duration(seconds: 8);

// VAR_UPDATE reliability (v3)
const int kVarUpdateTimeoutMs  = 200;
const int kVarUpdateMaxRetries = 5;

// Theme is now string-based (e.g. "default", "retro")

// ── Style / variant IDs ───────────────────────────────────────────────────
const int kStyleDefault = 0;
const int kStylePrimary = 1;
const int kStyleDim     = 2;
const int kStyleSuccess = 3;
const int kStyleWarning = 4;
const int kStyleDanger  = 5;

// ── String bitmask bits ───────────────────────────────────────────────────
const int kStrMaskLabel   = 0x01;
const int kStrMaskIcon    = 0x02;
const int kStrMaskOnText  = 0x04;
const int kStrMaskOffText = 0x08;
const int kStrMaskContent = 0x10;

// Widget type name for display
String widgetTypeName(int typeId) {
  switch (typeId) {
    case kWidgetButton:      return 'Button';
    case kWidgetSwitch:      return 'Switch';
    case kWidgetSlider:      return 'Slider';
    case kWidgetJoystick:    return 'Joystick';
    case kWidgetLed:         return 'LED';
    case kWidgetText:        return 'Text';
    case kWidgetMultiple:    return 'Multiple';
    case kWidgetSlideSwitch: return 'SlideSwitch';
    default:                 return 'Unknown';
  }
}
