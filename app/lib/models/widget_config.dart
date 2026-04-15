import 'protocol.dart';

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

  /// Height of the widget in canvas units (wire field SIZE, uint8).
  final int size;

  /// Aspect ratio × 10 (uint8). Width = size × (aspect / 10.0).
  final int aspect;

  /// Scale factor × 10 (uint8, v3). Default 10 = 1.0×.
  final int scale;

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

  /// Rotation as stored on the wire (int8, −90 to +90).
  /// Multiply by 2 to get display degrees.
  final int rotation;

  /// Computed width in canvas units.
  double get w => size * (aspect / 10.0);

  /// Computed height in canvas units.
  double get h => size.toDouble();

  /// Display rotation in degrees.
  double get rotationDegrees => rotation * 2.0;

  const WidgetConfig({
    required this.typeId,
    required this.widgetId,
    required this.x,
    required this.y,
    required this.size,
    required this.aspect,
    this.scale   = 10,
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
  List<String> get multipleItems {
    if (typeId != kWidgetMultiple || content.isEmpty) return [];
    return content.split('|').map((s) => s.trim()).toList();
  }

  @override
  String toString() =>
      'WidgetConfig(id=$widgetId, type=$typeName, label="$label", '
      'pos=($x,$y), size=$size, aspect=${aspect / 10.0} → '
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
  /// LED: [r, g, b, opacity]  (v3 – 4 bytes)
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
          outputs[w.widgetId] = [0, 0, 0, 0]; // R G B OPACITY
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
