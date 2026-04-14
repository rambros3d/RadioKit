import 'protocol.dart';

/// Configuration for a single UI widget, parsed from CONF_DATA payload.
class WidgetConfig {
  final int typeId;
  final int widgetId;

  /// Position in virtual 0-1000 coordinate space
  final double x;
  final double y;
  final double w;
  final double h;

  /// Human-readable label
  final String label;

  const WidgetConfig({
    required this.typeId,
    required this.widgetId,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.label,
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
      'pos=($x,$y), size=${w}x$h)';
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
