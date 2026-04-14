import 'protocol.dart';

/// Configuration for a single UI widget, parsed from a v2 CONF_DATA payload.
///
/// Coordinate system:
///   - Origin (0,0) is the bottom-left corner of the virtual canvas.
///   - X increases rightward; Y increases upward.
///   - [x] and [y] are the CENTER point of the widget.
///   - Canvas size depends on [orientation] (200×100 landscape / 100×200 portrait).
class WidgetConfig {
  final int typeId;
  final int widgetId;

  /// Center X in virtual canvas coordinates (uint8, 0–200).
  final double x;

  /// Center Y in virtual canvas coordinates, bottom-left origin (uint8, 0–200).
  final double y;

  final double w;
  final double h;

  /// Human-readable label.
  final String label;

  /// Rotation as stored on the wire (int8, −90 to +90).
  /// Multiply by 2 to get display degrees (−180° to +180°).
  final int rotation;

  /// Convenience: display degrees derived from wire rotation value.
  double get rotationDegrees => rotation * 2.0;

  const WidgetConfig({
    required this.typeId,
    required this.widgetId,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.label,
    this.rotation = 0,
  });

  /// Returns the number of input bytes this widget type uses.
  int get inputSize => kWidgetInputSize[typeId] ?? 0;

  /// Returns the number of output bytes this widget type uses.
  int get outputSize => kWidgetOutputSize[typeId] ?? 0;

  /// True if this widget sends data to Arduino (user-controllable).
  bool get hasInput => inputSize > 0;

  /// True if this widget receives data from Arduino (display only).
  bool get hasOutput => outputSize > 0;

  /// Type name for display purposes.
  String get typeName => widgetTypeName(typeId);

  @override
  String toString() =>
      'WidgetConfig(id=$widgetId, type=$typeName, label="$label", '
      'pos=($x,$y), size=${w}x$h, rot=${rotationDegrees}°)';
}

/// Holds the current state (values) for all widgets.
class RadioWidgetState {
  /// Input variable values keyed by widgetId.
  /// Button: int (0 or 1)
  /// Switch: int (0 or 1)
  /// Slider: int (0-100)
  /// Joystick: [x, y] each int8 -100..100 stored as two consecutive entries
  final Map<int, List<int>> inputValues;

  /// Output variable values keyed by widgetId.
  /// LED: int (0-4)
  /// Text: String
  final Map<int, dynamic> outputValues;

  const RadioWidgetState({
    required this.inputValues,
    required this.outputValues,
  });

  factory RadioWidgetState.initial(List<WidgetConfig> widgets) {
    final inputs = <int, List<int>>{};
    final outputs = <int, dynamic>{};

    for (final w in widgets) {
      if (w.hasInput) {
        if (w.typeId == kWidgetJoystick) {
          inputs[w.widgetId] = [0, 0]; // x, y
        } else {
          inputs[w.widgetId] = [0];
        }
      }
      if (w.hasOutput) {
        if (w.typeId == kWidgetText) {
          outputs[w.widgetId] = '';
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
