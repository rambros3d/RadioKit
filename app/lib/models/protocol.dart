/// Protocol constants for the RadioKit binary protocol v3.0
library protocol;

// BLE Service and Characteristic UUIDs
const String kRadioKitServiceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
const String kRadioKitCharUuid    = '0000FFE1-0000-1000-8000-00805F9B34FB';

// Packet framing
const int kStartByte = 0x55;

// Command identifiers
const int kCmdGetConf  = 0x01;
const int kCmdConfData = 0x02;
const int kCmdGetVars  = 0x03;
const int kCmdVarData  = 0x04;
const int kCmdSetInput = 0x05;
const int kCmdAck      = 0x06;
const int kCmdPing     = 0x07;
const int kCmdPong     = 0x08;
const int kCmdVarUpdate = 0x09; // v3: partial variable update with ACK

// Widget type identifiers
const int kWidgetButton   = 0x01;
const int kWidgetSwitch   = 0x02; // toggle button
const int kWidgetSlider   = 0x03;
const int kWidgetJoystick = 0x04;
const int kWidgetLed      = 0x05;
const int kWidgetText     = 0x06;
const int kWidgetMultiple = 0x07; // v3: segmented / multi-button

// Widget input sizes in bytes (app → device)
const Map<int, int> kWidgetInputSize = {
  kWidgetButton:   1,
  kWidgetSwitch:   1,
  kWidgetSlider:   1,
  kWidgetJoystick: 2,
  kWidgetLed:      0,
  kWidgetText:     0,
  kWidgetMultiple: 1,
};

// Widget output sizes in bytes (device → app)
// LED: 4 bytes — R G B OPACITY (v3)
const Map<int, int> kWidgetOutputSize = {
  kWidgetButton:   0,
  kWidgetSwitch:   0,
  kWidgetSlider:   0,
  kWidgetJoystick: 0,
  kWidgetLed:      4,
  kWidgetText:     32,
  kWidgetMultiple: 0,
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
const Duration kGetVarsInterval = Duration(milliseconds: 100);
const Duration kPingInterval    = Duration(seconds: 2);
const Duration kConfTimeout     = Duration(seconds: 5);

// VAR_UPDATE reliability (v3)
const int kVarUpdateTimeoutMs  = 200;
const int kVarUpdateMaxRetries = 5;

// ── Theme IDs (mirror RK_Config themes) ──────────────────────────────────────
const int kThemeDefault  = 0;
const int kThemeMinimal  = 1;
const int kThemeDark     = 2;
const int kThemeLight    = 3;
const int kThemeNeon     = 4;
const int kThemeRetro    = 5;
const int kThemeCustom   = 6;

// ── Style / variant IDs ───────────────────────────────────────────────────────
const int kStyleDefault = 0;
const int kStylePrimary = 1;
const int kStyleDim     = 2;
const int kStyleSuccess = 3;
const int kStyleWarning = 4;
const int kStyleDanger  = 5;

// ── String bitmask bits ───────────────────────────────────────────────────────
const int kStrMaskLabel   = 0x01;
const int kStrMaskIcon    = 0x02;
const int kStrMaskOnText  = 0x04;
const int kStrMaskOffText = 0x08;
const int kStrMaskContent = 0x10;

// Widget type name for display
String widgetTypeName(int typeId) {
  switch (typeId) {
    case kWidgetButton:   return 'Button';
    case kWidgetSwitch:   return 'Switch';
    case kWidgetSlider:   return 'Slider';
    case kWidgetJoystick: return 'Joystick';
    case kWidgetLed:      return 'LED';
    case kWidgetText:     return 'Text';
    case kWidgetMultiple: return 'Multiple';
    default:              return 'Unknown';
  }
}
