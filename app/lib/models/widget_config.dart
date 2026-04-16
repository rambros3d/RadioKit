import 'protocol.dart';

// ── Per-type base sizes in canvas units ──────────────────────────────────────
// These are the default H of each widget at scale=1.0.
// W = baseH * scale * (aspect / 10.0)
// H = baseH * scale
const Map<int, double> kWidgetBaseSize = {
  kWidgetButton:      10.0,
  kWidgetSwitch:      10.0,
  kWidgetSlider:      10.0,
  kWidgetJoystick:    20.0,
  kWidgetLed:          8.0,
  kWidgetText:         8.0,
  kWidgetMultiple:    10.0,
  kWidgetSlideSwitch:  8.0,
};

/// Represents a single item in a Multiple widget.
class MultipleItem {
  final String label;
  final String icon;
  const MultipleItem(this.label, this.icon);
}

/// Configuration for a single UI widget, parsed from a v3 CONF_DATA payload.
///
/// Coordinate system:
///   - Origin (0,0) is the bottom-left corner of the virtual canvas.
///   - X increases rightward; Y increases upward.
///   - [x] and [y] are the CENTER point of the widget.
class WidgetConfig {
  final int typeId;
  final int widgetId;

  /// Center X in virtual canvas coordinates (uint8).
  final double x;

  /// Center Y in virtual canvas coordinates, bottom-left origin (uint8).
  final double y;

  /// Scale factor × 10 (uint8). e.g. 20 = 2.0×.
  final int scale;

  /// Aspect ratio × 10 (uint8). e.g. 10 = 1.0 (square). 0 = use widget default.
  final int aspect;

  /// Style / color variant (uint8, v3). See kStyle* constants.
  final int style;

  /// Widget-specific variant byte (uint8, v3).
  /// Button: 0 = push/momentary, 1 = toggle
  /// Multiple: number of items (1–8)
  final int variant;

  /// String presence bitmask (uint8, v3). See kStrMask* constants.
  final int strMask;

  /// Human-readable label (present if kStrMaskLabel bit is set).
  final String label;

  /// Icon identifier string (present if kStrMaskIcon bit is set).
  final String icon;

  /// ON state label (present if kStrMaskOnText bit is set).
  final String onText;

  /// OFF state label (present if kStrMaskOffText bit is set).
  final String offText;

  /// Content string — pipe-delimited items for Multiple widget
  /// (present if kStrMaskContent bit is set).
  final String content;

  /// Rotation as stored on the wire (int16, degrees ÷ 2).
  /// Multiply by 2 to get display degrees.
  final int rotation;

  /// Scale as a float (scale / 10.0).
  double get scaleF => scale / 10.0;

  /// Aspect ratio as a float. Falls back to widget-type default if 0.
  double get aspectF {
    if (aspect != 0) return aspect / 10.0;
    return (kWidgetDefaultAspect[typeId] ?? 10) / 10.0;
  }

  /// Base height for this widget type in canvas units at scale 1.0.
  double get baseH => kWidgetBaseSize[typeId] ?? 10.0;

  /// Computed height in canvas units.
  double get h => baseH * scaleF;

  /// Computed width in canvas units.
  double get w => h * aspectF;

  /// Display rotation in degrees.
  double get rotationDegrees => rotation.toDouble();

  const WidgetConfig({
    required this.typeId,
    required this.widgetId,
    required this.x,
    required this.y,
    required this.scale,
    required this.aspect,
    this.style   = 0,
    this.variant = 0,
    this.strMask = 0,
    this.label   = '',
    this.icon    = '',
    this.onText  = '',
    this.offText = '',
    this.content = '',
    this.rotation = 0,
  });

  int get inputSize  => kWidgetInputSize[typeId]  ?? 0;
  int get outputSize => kWidgetOutputSize[typeId] ?? 0;
  bool get hasInput  => inputSize > 0;
  bool get hasOutput => outputSize > 0;
  String get typeName => widgetTypeName(typeId);

  /// For Multiple widget: parse pipe-delimited items from [content].
  /// Format is "label:icon|label:icon|..."
  List<MultipleItem> get multipleItems {
    if (typeId != kWidgetMultiple || content.isEmpty) return [];
    return content.split('|').map((s) {
      final parts = s.split(':');
      if (parts.length >= 2) {
        return MultipleItem(parts[0].trim(), parts[1].trim());
      } else {
        return MultipleItem(s.trim(), '');
      }
    }).toList();
  }

  @override
  String toString() =>
      'WidgetConfig(id=$widgetId, type=$typeName, label="$label", '
      'pos=($x,$y), scale=$scaleF× aspect=$aspectF → '
      '${w.toStringAsFixed(1)}×${h.toStringAsFixed(1)}, '
      'style=$style, variant=$variant, rot=${rotationDegrees}°)';
}

/// Holds the current state (values) for all widgets.
class RadioWidgetState {
  /// Input variable values keyed by widgetId.
  /// Button/Switch/Slider/Multiple: [value]
  /// Joystick: [x, y]
  final Map<int, List<int>> inputValues;

  /// Output variable values keyed by widgetId.
  /// LED: [state, r, g, b, opacity]  (v3 – 5 bytes)
  /// Text: String
  final Map<int, dynamic> outputValues;

  const RadioWidgetState({
    required this.inputValues,
    required this.outputValues,
  });

  factory RadioWidgetState.initial(List<WidgetConfig> widgets) {
    final inputs  = <int, List<int>>{};
    final outputs = <int, dynamic>{};

    for (final w in widgets) {
      if (w.hasInput) {
        if (w.typeId == kWidgetJoystick) {
          inputs[w.widgetId] = [0, 0];
        } else {
          inputs[w.widgetId] = [0];
        }
      }
      if (w.hasOutput) {
        if (w.typeId == kWidgetText) {
          outputs[w.widgetId] = '';
        } else if (w.typeId == kWidgetLed) {
          outputs[w.widgetId] = [0, 0, 0, 0, 0]; // STATE R G B OPACITY
        } else {
          outputs[w.widgetId] = 0;
        }
      }
    }

    return RadioWidgetState(inputValues: inputs, outputValues: outputs);
  }

  RadioWidgetState copyWithInput(int widgetId, List<int> values) {
    final newInputs = Map<int, List<int>>.from(inputValues);
    newInputs[widgetId] = values;
    return RadioWidgetState(inputValues: newInputs, outputValues: outputValues);
  }

  RadioWidgetState copyWithOutput(int widgetId, dynamic value) {
    final newOutputs = Map<int, dynamic>.from(outputValues);
    newOutputs[widgetId] = value;
    return RadioWidgetState(inputValues: inputValues, outputValues: newOutputs);
  }
}
